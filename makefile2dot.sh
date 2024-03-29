#!/usr/bin/env bash

set -euo pipefail

# https://github.com/bibermann/makefile2dot

if ! [[ $# -eq 3 ]] ; then
    echo -e "Usage:\n\t$0 WORDS_PER_LINE RANKSEP SPLINES"
    echo -e "\t\tWORDS_PER_LINE: number of words per line in comments; example: 2, 3, 6"
    echo -e "\t\tRANKSEP: see https://www.graphviz.org/doc/info/attrs.html#d:ranksep; examples: 0, 0.5, 1, 2"
    echo -e "\t\tSPLINES: see https://www.graphviz.org/doc/info/attrs.html#d:splines; examples: spline, polyline, ortho, curved, line"
    exit 1
fi

WORDS_PER_LINE=$1
RANKSEP=$2
SPLINES=$3

case $SPLINES in
    ortho|curved)
        # Because else we get one of the following errors:
        # - Warning: Orthogonal edges do not currently handle edge labels. Try using xlabels.
        # - Warning: edge labels with splines=curved not supported in dot - use xlabels
        LABEL_ATTRIBUTE_NAME=xlabel
        ;;
    *)
        LABEL_ATTRIBUTE_NAME=label
        ;;
esac

split_each_nth_word()
{
    # Usage: split_each_nth_word <nth> <separator> <input...>
    # Prints <input...> with <separator> inserted after each <nth> word.

    nth=$1
    separator=$2
    shift 2
    input="$@"
    counter=0
    splitted=""
    for word in $input; do
        if [[ $counter -gt 0 ]]; then
            splitted="$splitted "
        fi
        splitted="$splitted$word"
        counter=$((counter+1))
        if [[ $counter -ge $nth ]]; then
            splitted="$splitted$separator"
            counter=0
        fi
    done
    echo "$splitted"
}

escape_for_dot()
{
    # Usage: escape <input...>
    # Prints <input...> escaped for dot node names
    escaped="$@"
    escaped=${escaped//-/_}
    escaped=${escaped// /_}
    echo "$escaped"
}

lines=()
while read; do
    lines+=( "$REPLY" )
done

spaces="[[:blank:]]*"
target_begin="[^[:blank:]=#.]"
target="$target_begin[^[:blank:]=#]*"
REGEX_GROUP_COMMENT="^##@$spaces(.*)"
REGEX_PHONY_TARGET_COMMENT="^\\.PHONY$spaces:$spaces($target)$spaces#+$spaces(.*)"
REGEX_PHONY_TARGET_DOCUMENTED_COMMENT="^\\.PHONY$spaces:$spaces($target)$spaces##$spaces(.*)"

recipeprefix=$'\t'
recipe_begin="^$recipeprefix$spaces"
command_begin="[^[:blank:]#]"
REGEX_RECIPE="$recipe_begin$command_begin"
REGEX_ECHO_OR_NOOP="$recipe_begin@?(echo |:|#|\\\$\((info|warning|error))"

REGEX_TARGET_REST="^($target)$spaces:($|[[:blank:]].*)"
REGEX_TARGET_DEPENDENCIES="^($target)$spaces:$spaces($target_begin[^#]*)"

REGEX_COMMENT="#+$spaces(.*)"
REGEX_DOCUMENTED_COMMENT="##$spaces(.*)"

# header
DOT=$(echo -e "digraph G {\n  graph [nodesep=\"0.1\", ranksep=\"$RANKSEP\"];\n  splines=\"$SPLINES\";")

# find all targets and those who have own recipes
all_targets=()
targets_with_recipes=()
current_target=""
for line in "${lines[@]}"; do
    if [[ $line =~ $REGEX_TARGET_REST ]]; then  # line is target declaration
        current_target="${BASH_REMATCH[1]}"
        all_targets+=( "$current_target" )
    else
        if ! [ -z "$current_target" ]; then
            if [[ $line =~ $REGEX_RECIPE ]] && ! [[ $line =~ $REGEX_ECHO_OR_NOOP ]]; then  # line has command different than echo/noop
                targets_with_recipes+=( "$current_target" )
                current_target=""
            fi
        fi
    fi
done

# add clusters and nodes
nested=0
phony_target=""
phony_comment=""
phony_is_documented_comment=""
for line in "${lines[@]}"; do
    if [[ $line =~ $REGEX_GROUP_COMMENT ]]; then  # line is group comment
        # add cluster
        if [[ $nested -gt 0 ]]; then  # need to close cluster
            nested=0
            DOT=$(echo -e "$DOT\n  }")
        fi
        group="${BASH_REMATCH[1]}"
        group_escaped="$(escape_for_dot $group)"
        DOT=$(echo -e "$DOT\n  subgraph cluster_$group_escaped {\n    label=\"$group\";\n    style=\"rounded, filled\"; color=gray; fillcolor=\"#eeeeee\"")
        nested=$((nested+1))
    elif [[ $line =~ $REGEX_PHONY_TARGET_COMMENT ]]; then  # line is phony declaration
        phony_target="${BASH_REMATCH[1]}"
        phony_comment="${BASH_REMATCH[2]}"
        if [[ $line =~ $REGEX_PHONY_TARGET_DOCUMENTED_COMMENT ]]; then
            phony_is_documented_comment="true"
        else
            phony_is_documented_comment="false"
        fi
    elif [[ $line =~ $REGEX_TARGET_REST ]]; then  # line is target declaration
        # add node
        target="${BASH_REMATCH[1]}"
        target_escaped="$(escape_for_dot $target)"
        rest="${BASH_REMATCH[2]}"
        if [[ $line =~ $REGEX_TARGET_DEPENDENCIES ]]; then  # target has dependencies
            penwidth=1
        else
            penwidth=3
        fi
        if printf '%s\n' ${targets_with_recipes[@]} | grep -q -P "^$target\$"; then  # target has own recipes
            style="rounded, filled"
        else
            style="rounded, filled, dashed"
        fi
        if [[ $rest =~ $REGEX_DOCUMENTED_COMMENT ]] || [[ "$phony_target" == "$target" && "$phony_is_documented_comment" == "true" ]]; then  # target has documented comment
            fillcolor=lightblue
        else
            fillcolor=lightgray
        fi
        if [[ $rest =~ $REGEX_COMMENT ]]; then  # target has comment
            comment="${BASH_REMATCH[1]}"
        elif [[ "$phony_target" == "$target" ]]; then  # target has comment defined in previous .PHONY declaration
            comment="$phony_comment"
        else
            comment=""
        fi
        if ! [ -z "$comment" ]; then
            label="<$target<BR /><FONT POINT-SIZE=\"10\">$(split_each_nth_word $WORDS_PER_LINE "<BR />" $comment)</FONT>>"
        else
            label="\"$target\""
        fi
        DOT=$(echo -e "$DOT\n    $target_escaped[shape=box, style=\"$style\", fillcolor=$fillcolor, penwidth=$penwidth, label=$label];")
    fi
done

if [[ $nested -gt 0 ]]; then  # need to close cluster
    DOT=$(echo -e "$DOT\n  }")
fi

# add dependencies
for line in "${lines[@]}"; do
    if [[ $line =~ $REGEX_TARGET_DEPENDENCIES ]]; then
        target="${BASH_REMATCH[1]}"
        target_escaped="$(escape_for_dot $target)"
        dependencies="${BASH_REMATCH[2]}"
        counter=0
        dependencies_array=( $dependencies )
        dependencies_count=${#dependencies_array[@]}
        for dependency in $dependencies; do
            counter=$((counter+1))
            if [[ $dependencies_count -eq 1 ]]; then
                label=""
            else
                label=$counter
            fi
            dependency_escaped=${dependency//-/_}
            DOT=$(echo -e "$DOT\n  $dependency_escaped -> $target_escaped [color=\"#ff0000aa\", $LABEL_ATTRIBUTE_NAME=\"$label\"];")

            if ! printf '%s\n' ${all_targets[@]} | grep -q -P "^$dependency\$"; then  # dependency is no known target
                1>&2 echo "Warning: Dependency '$dependency' not found in target declarations."
            fi
        done
    fi
done

# footer
DOT=$(echo -e "$DOT\n}")

echo "$DOT"
