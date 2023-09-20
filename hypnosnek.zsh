function conda_client() {
    for client (micromamba mamba conda); do
        whence "$client" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            $client $@
            return $?
        fi
    done
}

function try_activate_venv() {
    max_search_height=20

    curdirname="${PWD##*/}"
    curdirname="${curdirname:-/}"

    export local_virtual_env_loc=""
    export local_virtual_env_found=false
    export local_conda_env_loc=""
    export local_conda_env_found=false

    search_path="${PWD:A}"

    for (( i=1; i <= $max_search_height; i++ )); do
        if [ -r "$search_path/.venv/bin/activate" ]; then
            local_virtual_env_loc="$search_path/.venv"
            local_virtual_env_found=true
        fi
        if [ -d "$search_path/.conda/envs/$curdirname" ]; then
            local_conda_env_loc="$search_path/.conda/envs/$curdirname"
            local_conda_env_found=true
        fi
        if [ "$local_virtual_env_found" = true ] || [ "$local_conda_env_found" = true ]; then
            break
        fi
        if [ "$search_path" = "/" ]; then
            return 1
        fi
        search_path="${${search_path/..}:A}"
    done

    if [[ -v VIRTUAL_ENV ]]; then
        if [ "${local_virtual_env_found}" = true ] && [ "${VIRTUAL_ENV:A}" = "$local_virtual_env_loc" ]; then
            return 0
        else
            whence deactivate > /dev/null 2>&1 
            if [ $? -eq 0 ]; then
                deactivate
            fi
            unset VIRTUAL_ENV
            unset VIRTUAL_ENV_PROMPT
        fi
    fi

    if [[ -v CONDA_PREFIX ]]; then
        if [ "$local_conda_env_found" = true ] && [ "${CONDA_PREFIX:A}" = "$local_conda_env_loc" ]; then
            return 0
        else
            conda_client deactivate
            unset CONDA_PREFIX
            unset CONDA_DEFULT_ENV
            unset CONDA_PROMPT_MODIFIER
        fi
    fi

    if [ "$local_virtual_env_found" = true ]; then
        try_source "$local_virtual_env_loc/bin/activate"
        return $?
    fi

    if [ "$local_conda_env_found" = true ]; then
        conda_client activate "$local_conda_env_loc"
        return $?
    fi

    return 0
}

function venv() {
    curdirname="${PWD##*/}"
    curdirname="${curdirname:-/}"
 
    try_activate_venv
    if [ "$local_virtual_env_found" = true ]; then
        env_rel_path="$(grealpath --relative-to="$PWD" "$local_virtual_env_loc")"
        echo "$(antsy -fg yellow)$(antsy -s bold)caution!$(antsy -s nobold) virtual environment found at$(antsy -r) ./$env_rel_path"
        if [ $# = 0 ] && [ "$local_virtual_env_loc" = "${PWD:A}/.venv" ]; then
            echo "$(antsy -s bold -fg red)it will be replaced!$(antsy -r)"
        fi
    fi
    if [ "$local_conda_env_found" = true ]; then
        env_rel_path="$(grealpath --relative-to="$PWD" "$local_conda_env_loc")"
        echo "$(antsy -fg yellow)$(antsy -s bold)caution!$(antsy -s nobold) conda environment found at$(antsy -r)   ./$env_rel_path"
        if [ $# = 1 ] && [ "$1" = "-c" ] && [ "$local_conda_env_loc" = "${PWD:A}/.conda/envs/$curdirname" ]; then
            echo "$(antsy -s bold -fg red)it will be replaced!$(antsy -r)"
        fi
    fi
    if [ "$local_virtual_env_found" = true ] || [ "$local_conda_env_found" = true ]; then
        echo -n "proceed? "
        confirm
        if [ $? != 0 ]; then
            return 0
        fi
    fi
    if [ $# = 1 ] && [ "$1" = "-c" ]; then 
        rm -rf "./.conda/envs/$curdirname"
        conda_spec_path="$(grealpath --relative-to="$HOME" "$ZDOTDIR/default_conda_spec.yml")"
        echo "$(antsy -s underline -fg yellow)Note: creating conda environment based on spec at ~/$conda_spec_path $(antsy -r)"
        conda_client create -r ./.conda -n "$curdirname" -f "$ZDOTDIR/default_conda_spec.yml"
    elif [ $# = 0 ]; then
        rm -rf "./.venv"
        conda_client activate dev
        python -m venv --clear --upgrade-deps .venv
        conda_client deactivate
    else
        echo "usage: venv [-c]"
    fi
    try_activate_venv
}


function prompt_python_env_type() {
    if [ "$local_virtual_env_found" = true ] && [ "$local_conda_env_found" = true ]; then
        p10k segment -s HOT -b red -i '' -t "$(antsy -s bold)venv$(antsy -s notbold) / $(antsy -s faint)conda$(antsy -s notfaint)"
    elif [ "$local_virtual_env_found" = true ] && [ "$local_conda_env_found" = false ]; then
        p10k segment -s HOT -b green -i '󰙴' -t "$(antsy -s bold)venv$(antsy -s notbold)"
    elif [ "$local_virtual_env_found" = false ] && [ "$local_conda_env_found" = true ]; then
        p10k segment -s HOT -b green -i '󰙴' -t "$(antsy -s bold)conda$(antsy -s notbold)"
    fi
}


