#!/bin/bash

# File to store project-directory pairs
PROJECTS_FILE="$HOME/.bourbon_projects"

# Function to extract project name from pyproject.toml
get_project_name() {
    while IFS='=' read -r key value; do
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [[ $key == "name" ]]; then
            project_name="${value//[\"\']}"
            break
        fi
    done < pyproject.toml
    if [[ -z $project_name ]]; then
        echo "Project name not found in pyproject.toml"
        return 1
    fi
}

# Function to add current project to PROJECTS_FILE
add_project() {
    if [ ! -f "pyproject.toml" ]; then
        echo "Error: No pyproject.toml file found in the current directory."
        return 1
    fi

    get_project_name
    if [ $? -ne 0 ]; then
        return 1
    fi
    local project_name=$project_name

    if grep -q "^$project_name|" $PROJECTS_FILE 2>/dev/null; then
        echo "Error: Project '$project_name' is already added."
        return 1
    fi

    local project_dir=$(pwd)
    echo "$project_name|$project_dir" >> $PROJECTS_FILE
    echo "Added $project_name to bourbon projects."
}

# Function to change directory to a project's directory and activate the virtual environment
cd_project() {
    if [ ! -f $PROJECTS_FILE ]; then
        echo "Error: No projects found. Add a project using 'bourbon add'."
        return 1
    fi

    local project_name="$1"
    local project_dir=$(grep "^$project_name|" $PROJECTS_FILE | cut -d '|' -f 2)

    if [ -z "$project_dir" ]; then
        echo "Error: Project '$project_name' not found."
        return 1
    fi

    cd "$project_dir" || { echo "Error: Could not change directory to '$project_dir'."; return 1; }

    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    else
        echo "Warning: Virtual environment not found in the project directory."
    fi
}

# Function to list all added projects
list_projects() {
    if [ ! -f $PROJECTS_FILE ]; then
        echo "No projects added."
        return 0
    fi

    cut -d '|' -f 1 $PROJECTS_FILE
}

# Function to remove a project and its directory from PROJECTS_FILE
remove_project() {
    if [ ! -f $PROJECTS_FILE ]; then
        echo "Error: No projects found. Add a project using 'bourbon add'."
        return 1
    fi

    local project_name="$1"

    if [ -z "$project_name" ]; then
        if [ ! -f "pyproject.toml" ]; then
            echo "Error: No pyproject.toml file found in the current directory."
            return 1
        fi

        get_project_name
        project_name=$project_name
    fi

    if ! grep -q "^$project_name|" $PROJECTS_FILE; then
        echo "Error: Project '$project_name' not found."
        return 1
    fi

    local temp_file=$(mktemp)
    grep -v "^$project_name|" $PROJECTS_FILE > $temp_file
    mv $temp_file $PROJECTS_FILE
    echo "Removed $project_name from bourbon projects."
}

# Function to process arguments and invoke the appropriate function
bourbon() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: bourbon <command> [<args>]"
        echo ""
        echo "Commands:"
        echo "  add         Add the current project to bourbon projects."
        echo "  <project>   Change directory to the specified project and activate the virtual environment."
        echo "  list        List all added bourbon projects."
        echo "  remove      Remove a project from bourbon projects."
        echo "              Use 'remove <project>' to specify a project, or 'remove' to remove the current project."
        return 0
    fi

    local command="$1"
    shift

    case $command in
        add)
            add_project
            ;;
        list)
            list_projects
            ;;
        remove)
            remove_project "$@"
            ;;
        *)
            cd_project "$command"
            ;;
    esac
}
