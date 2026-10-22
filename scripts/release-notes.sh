#!/usr/bin/env bash
# Usage: scripts/release-notes.sh <previous-tag> <new-tag>
#
# Print release notes in Markdown for the commits in <previous-tag>..HEAD.
# Commits follow Conventional Commits. Sections: Breaking changes, Added
# (feat), Fixed (fix), Changed (refactor, perf), Misc (all other types).
# A commit is breaking if its type ends with "!" or its body has a
# "BREAKING CHANGE:" line. "fixes #N", "closes #N", "resolves #N" in a
# commit body link the solved issues. "refs #N" links a related issue.

set -euo pipefail

prev=$1
new=$2
repo=$(gh repo view --json url -q .url)
subject_re='^([a-z]+)(\([^)]*\))?(!)?: (.+)$'
breaking=
added=
fixed=
changed=
misc=

issue_list() {
    grep -ioE "$1" <<<"$2" | grep -oE '#[0-9]+' | paste -sd, - | sed 's/,/, /g' || true
}

while IFS= read -r -d $'\x1e' record; do
    record=${record#$'\n'}
    subject=${record%%$'\x1f'*}
    body=${record#*$'\x1f'}
    [[ $subject =~ $subject_re ]] || continue
    type=${BASH_REMATCH[1]}
    text=${BASH_REMATCH[4]}

    footer=$(sed -nE 's/^BREAKING[ -]CHANGE: *//p' <<<"$body")
    solved=$(issue_list '(fix(e[sd])?|close[sd]?|resolve[sd]?):? +#[0-9]+' "$body")
    related=$(issue_list 'refs?:? +#[0-9]+' "$body")
    links=${solved:+fixes $solved}${solved:+${related:+; }}${related:+refs $related}

    is_breaking=
    [[ -n ${BASH_REMATCH[3]} || -n $footer ]] && is_breaking=1
    line="- ${footer:-$text}${links:+ ($links)}"

    if [[ $is_breaking ]]; then
        breaking+="$line"$'\n'
    else
        case $type in
        feat) added+="$line"$'\n' ;;
        fix) fixed+="$line"$'\n' ;;
        refactor | perf) changed+="$line"$'\n' ;;
        *) misc+="$line"$'\n' ;;
        esac
    fi
done < <(git log --reverse --format='%s%x1f%b%x1e' "$prev..HEAD")

section() {
    [[ -n $2 ]] && printf '## %s\n\n%s\n' "$1" "$2"
    return 0
}

section "⚠️ Breaking changes" "$breaking"
section "Added" "$added"
section "Fixed" "$fixed"
section "Changed" "$changed"
section "Misc" "$misc"
echo "**Full Changelog**: $repo/compare/$prev...$new"
