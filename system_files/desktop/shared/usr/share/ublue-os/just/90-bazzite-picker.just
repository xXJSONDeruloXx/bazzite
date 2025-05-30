// filepath: /Users/kurt/Developer/bazzite/system_files/desktop/shared/usr/share/ublue-os/just/90-bazzite-picker.just
# vim: set ft=make :

# Interactive picker for ujust recipes
pick:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    # Clear the screen for a clean display
    clear
    
    echo "${bold}Available ujust recipes:${normal}"
    echo "Use arrow keys to navigate, Enter to select, Esc to exit"
    echo
    
    # Temporary directory to store categorized recipes
    TEMP_DIR=$(mktemp -d)
    
    # Find all the .just files in the /usr/share/ublue-os/just/ directory
    JUST_FILES=(/usr/share/ublue-os/just/*.just)
    
    # Helper function to get a clean category name from filename
    get_category_name() {
        local filename=$1
        # Extract the category from the filename (e.g., 80-bazzite.just -> Bazzite)
        # Remove numbers and dashes at the beginning, remove .just extension, capitalize first letter
        name=$(echo "$filename" | sed -E 's/^[0-9]+-//' | sed 's/\.just$//' | sed -E 's/(^|-)([a-z])/\U\2/g')
        echo "$name"
    }
    
    # Process each file to create categorized recipe files
    for file in "${JUST_FILES[@]}"; do
        filename=$(basename "$file")
        
        # Skip the current picker file to avoid recursion
        if [[ "$filename" == "90-bazzite-picker.just" ]]; then
            continue
        fi
        
        # Get a clean category name
        category=$(get_category_name "$filename")
        
        # Create a file for this category
        cat_file="${TEMP_DIR}/${filename}"
        # Add the category header
        echo ":: ${category}" > "$cat_file"
        
        # Extract recipes from this file
        while IFS= read -r line; do
            # Look for lines with recipe definitions (ending with colon)
            if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*:.*$ ]]; then
                recipe="${BASH_REMATCH[1]}"
                
                # Skip if it's a private recipe (starts with underscore) or an alias
                if [[ "$recipe" == _* || "$line" =~ ^[[:space:]]*alias ]]; then
                    continue
                fi
                
                # Skip if it has the [private] attribute
                if [[ "$line" =~ \[private\] ]]; then
                    continue
                fi
                
                # Look for description in the previous line (comments starting with #)
                description=""
                prev_line=$(grep -B1 -E "^[[:space:]]*$recipe[[:space:]]*:" "$file" | head -n1)
                if [[ "$prev_line" =~ ^[[:space:]]*#[[:space:]]*(.*) ]]; then
                    description="${BASH_REMATCH[1]}"
                    echo "$recipe|$description" >> "$cat_file"
                else
                    echo "$recipe|" >> "$cat_file"
                fi
            fi
        done < "$file"
        
        # Check if we found any recipes for this file
        if [[ $(wc -l < "$cat_file") -eq 1 ]]; then
            # Only the header line exists, no recipes found
            rm "$cat_file"
        fi
    done
    
    # Create the final formatted file for fzf
    FINAL_FILE="${TEMP_DIR}/recipes.txt"
    touch "$FINAL_FILE"
    
    # Combine all category files into the final file
    for cat_file in "${TEMP_DIR}"/*.just; do
        if [[ -f "$cat_file" ]]; then
            cat "$cat_file" >> "$FINAL_FILE"
            echo "" >> "$FINAL_FILE"  # Add a blank line between categories
        fi
    done
    
    # Check if fzf is available, otherwise fall back to a simpler selection method
    if command -v fzf &> /dev/null; then
        # Create separate files for each category to use with fzf tabs
        declare -a categories
        declare -a category_files
        
        # Extract all categories from the final file
        while read -r line; do
            if [[ "$line" =~ ^::[[:space:]](.*)$ ]]; then
                category="${BASH_REMATCH[1]}"
                categories+=("$category")
                # Create a file for recipes in this category
                cat_file="${TEMP_DIR}/${category// /_}.txt"
                category_files+=("$cat_file")
                touch "$cat_file"
                
                # Extract recipes for this category
                in_category=1
                while IFS= read -r recipe_line; do
                    # If we hit another category header, break
                    if [[ "$recipe_line" =~ ^::[[:space:]] && "$recipe_line" != ":: $category" ]]; then
                        break
                    fi
                    
                    # Skip the category header
                    if [[ "$recipe_line" =~ ^::[[:space:]] ]]; then
                        continue
                    fi
                    
                    # Add recipe to the category file
                    if [[ -n "$recipe_line" ]]; then
                        echo "$recipe_line" | sed 's/|/ - /g' >> "$cat_file"
                    fi
                done < <(grep -A 100 "^:: $category" "$FINAL_FILE" 2>/dev/null)
            fi
        done < "$FINAL_FILE"
        
        # Create tab navigation options
        tab_options=""
        for i in "${!categories[@]}"; do
            if [ $i -gt 0 ]; then
                tab_options+=",$i:change-preview(cat ${category_files[$i]})+change-prompt(Choose a ${categories[$i]} recipe: )"
            else
                # Special handling for first tab (default)
                tab_options+="$i:change-preview(cat ${category_files[$i]})+change-prompt(Choose a ${categories[$i]} recipe: )"
            fi
        done
        
        # Create tab navigation script
        echo '#!/bin/bash' > "${TEMP_DIR}/tab_nav.sh"
        echo '' >> "${TEMP_DIR}/tab_nav.sh"
        echo '# Get current tab from input or use default' >> "${TEMP_DIR}/tab_nav.sh"
        echo 'current_tab="${1:-0}"' >> "${TEMP_DIR}/tab_nav.sh"
        echo 'direction="${2:-next}"' >> "${TEMP_DIR}/tab_nav.sh"
        echo '' >> "${TEMP_DIR}/tab_nav.sh"
        echo "# Define total tabs" >> "${TEMP_DIR}/tab_nav.sh"
        echo "total_tabs=${#categories[@]}" >> "${TEMP_DIR}/tab_nav.sh"
        echo '' >> "${TEMP_DIR}/tab_nav.sh"
        echo '# Calculate next tab' >> "${TEMP_DIR}/tab_nav.sh"
        echo 'if [ "$direction" = "next" ]; then' >> "${TEMP_DIR}/tab_nav.sh"
        echo '  next_tab=$((current_tab + 1))' >> "${TEMP_DIR}/tab_nav.sh"
        echo '  if [ $next_tab -ge $total_tabs ]; then' >> "${TEMP_DIR}/tab_nav.sh"
        echo '    next_tab=0' >> "${TEMP_DIR}/tab_nav.sh"
        echo '  fi' >> "${TEMP_DIR}/tab_nav.sh"
        echo 'else' >> "${TEMP_DIR}/tab_nav.sh"
        echo '  next_tab=$((current_tab - 1))' >> "${TEMP_DIR}/tab_nav.sh"
        echo '  if [ $next_tab -lt 0 ]; then' >> "${TEMP_DIR}/tab_nav.sh"
        echo '    next_tab=$((total_tabs - 1))' >> "${TEMP_DIR}/tab_nav.sh"
        echo '  fi' >> "${TEMP_DIR}/tab_nav.sh"
        echo 'fi' >> "${TEMP_DIR}/tab_nav.sh"
        echo '' >> "${TEMP_DIR}/tab_nav.sh"
        echo '# Output next tab' >> "${TEMP_DIR}/tab_nav.sh"
        echo 'echo $next_tab' >> "${TEMP_DIR}/tab_nav.sh"
        
        chmod +x "${TEMP_DIR}/tab_nav.sh"
        
        # Create key bindings for tab navigation with left/right arrows
        key_bindings=""
        for i in "${!categories[@]}"; do
            # When on tab i, show the correct category file
            key_bindings+=",ctrl-$i:change-preview(cat ${category_files[$i]})+change-prompt(Choose a ${categories[$i]} recipe: )+execute-silent(echo $i > ${TEMP_DIR}/current_tab.txt)"
        done
        
        # Add specific left/right arrow key bindings for tab navigation
        key_bindings+=",left:preview-up,right:preview-down"
        
        # Additional navigation mappings
        for i in "${!categories[@]}"; do
            if [ $i -eq 0 ]; then
                key_bindings+=",home:execute-silent(echo $i)"
            fi
        done
        
        # Create the initial preview
        initial_preview="cat ${category_files[0]}"
        
        # Prepare tab header - format category names as tabs
        tab_header=""
        for i in "${!categories[@]}"; do
            if [ $i -eq 0 ]; then
                # First tab - active
                tab_header+="[${categories[$i]}] "
            else
                # Other tabs - inactive
                tab_header+=" ${categories[$i]} "
            fi
        done
        
        # Initial prompt
        init_prompt="Choose a ${categories[0]} recipe: "
        
        # Create a function to render tab header
        echo '#!/bin/bash' > "${TEMP_DIR}/render_tabs.sh"
        echo 'current_tab=${1:-0}' >> "${TEMP_DIR}/render_tabs.sh"
        echo 'tabs=(' >> "${TEMP_DIR}/render_tabs.sh"
        for category in "${categories[@]}"; do
            echo "  \"$category\"" >> "${TEMP_DIR}/render_tabs.sh"
        done
        echo ')' >> "${TEMP_DIR}/render_tabs.sh"
        
        echo 'header="  "' >> "${TEMP_DIR}/render_tabs.sh"
        echo 'for i in "${!tabs[@]}"; do' >> "${TEMP_DIR}/render_tabs.sh"
        echo '  if [ $i -eq $current_tab ]; then' >> "${TEMP_DIR}/render_tabs.sh"
        echo '    header+="[\033[1;36m${tabs[$i]}\033[0m] "' >> "${TEMP_DIR}/render_tabs.sh"
        echo '  else' >> "${TEMP_DIR}/render_tabs.sh"
        echo '    header+=" ${tabs[$i]} "' >> "${TEMP_DIR}/render_tabs.sh"
        echo '  fi' >> "${TEMP_DIR}/render_tabs.sh"
        echo 'done' >> "${TEMP_DIR}/render_tabs.sh"
        echo 'header+="\n\n  ← → Tab Navigation | ↑ ↓ Navigate | Enter: Select | Esc: Exit"' >> "${TEMP_DIR}/render_tabs.sh"
        echo 'echo -e "$header"' >> "${TEMP_DIR}/render_tabs.sh"
        chmod +x "${TEMP_DIR}/render_tabs.sh"
        
        # Initialize current tab file
        echo "0" > "${TEMP_DIR}/current_tab.txt"
        
        # Initial header
        initial_header=$("${TEMP_DIR}/render_tabs.sh" 0)
        
        # Create simple tab selector
        echo '#!/bin/bash' > "${TEMP_DIR}/switch_tab.sh"
        echo 'tab=$1' >> "${TEMP_DIR}/switch_tab.sh"
        echo 'cat "$2" | sed "s/|/ - /g"' >> "${TEMP_DIR}/switch_tab.sh"
        chmod +x "${TEMP_DIR}/switch_tab.sh"
        
        # Create list of tabs for the menu
        TABS_MENU_FILE="${TEMP_DIR}/tabs_menu.txt"
        for i in "${!categories[@]}"; do
          echo "${categories[$i]}" >> "$TABS_MENU_FILE"
        done
        
        # First, let user select a category
        current_tab=0
        while true; do
            # Show category options with current one highlighted
            clear
            echo "${bold}Available ujust recipes by category:${normal}"
            echo "Use arrow keys to navigate, Enter to select a category, Esc to exit"
            echo
            echo "${green}${bold}Categories:${normal}"
            
            for i in "${!categories[@]}"; do
                if [ $i -eq $current_tab ]; then
                    echo "${cyan}${bold}▶ ${categories[$i]}${normal}"
                else
                    echo "  ${categories[$i]}"
                fi
            done
            
            # Now show recipes for the current tab
            echo
            echo "${green}${bold}Recipes in ${categories[$current_tab]}:${normal}"
            cat "${category_files[$current_tab]}" | sed 's/|/ - /g' | cat -n
            
            # Get keystroke and handle arrow keys properly
            read -sn1 key
            if [[ "$key" == $'\e' ]]; then
                read -sn2 -t 0.001 arrow
                if [[ "$arrow" == "[A" ]]; then  # Up arrow
                    current_tab=$((current_tab - 1))
                    if [ $current_tab -lt 0 ]; then
                        current_tab=$((${#categories[@]} - 1))
                    fi
                elif [[ "$arrow" == "[B" ]]; then  # Down arrow
                    current_tab=$((current_tab + 1))
                    if [ $current_tab -ge ${#categories[@]} ]; then
                        current_tab=0
                    fi
                else
                    # Escape key pressed (not followed by arrow sequence)
                    echo "Exiting without running any recipe."
                    rm -rf "$TEMP_DIR"
                    exit 0
                fi
            elif [[ "$key" == "" ]]; then  # Enter key
                # Show recipe selection for this tab
                clear
                echo "${bold}Select a recipe from ${categories[$current_tab]}:${normal}"
                echo "Enter a number or 'q' to go back to category selection"
                echo
                recipes=()
                while IFS='|' read -r recipe description; do
                    recipes+=("$recipe")
                    if [[ -n "$description" ]]; then
                        echo "$((${#recipes[@]})) $recipe - $description"
                    else
                        echo "$((${#recipes[@]})) $recipe"
                    fi
                done < "${category_files[$current_tab]}"
                
                echo
                read -p "Enter recipe number (1-${#recipes[@]}): " recipe_num
                
                if [[ "$recipe_num" == "q" ]]; then
                    continue  # Go back to category selection
                fi
                
                # Validate input
                if ! [[ "$recipe_num" =~ ^[0-9]+$ ]] || [ "$recipe_num" -lt 1 ] || [ "$recipe_num" -gt "${#recipes[@]}" ]; then
                    echo "Invalid selection. Press any key to continue..."
                    read -sn1
                    continue
                fi
                
                # Get the selected recipe
                selected="${recipes[$((recipe_num-1))]}"
                break
            fi
        done
        
        # If user pressed Esc or Ctrl+C
        if [[ -z "$selected" ]]; then
            echo "Exiting without running any recipe."
            rm -rf "$TEMP_DIR"
            exit 0
        fi
    else
        # Fallback to a simpler method if fzf isn't available
        echo "${bold}Available categories:${normal}"
        
        # List categories first
        categories=()
        i=1
        while read -r line; do
            if [[ "$line" =~ ^::[[:space:]](.*)$ ]]; then
                categories+=("${BASH_REMATCH[1]}")
                echo "$i) ${BASH_REMATCH[1]}"
                i=$((i+1))
            fi
        done < "$FINAL_FILE"
        
        # Prompt to select a category
        echo
        read -p "Select a category (1-${#categories[@]}, or 'q' to quit): " cat_choice
        
        if [[ "$cat_choice" == "q" ]]; then
            echo "Exiting without running any recipe."
            rm -rf "$TEMP_DIR"
            exit 0
        fi
        
        # Validate input
        if ! [[ "$cat_choice" =~ ^[0-9]+$ ]] || [ "$cat_choice" -lt 1 ] || [ "$cat_choice" -gt "${#categories[@]}" ]; then
            echo "Invalid selection. Exiting."
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        
        selected_category="${categories[$((cat_choice-1))]}"
        
        # Now show recipes for the selected category
        echo
        echo "${bold}Recipes in ${selected_category}:${normal}"
        
        # Extract recipes for this category
        cat_recipes=()
        in_selected_category=0
        i=1
        
        while read -r line; do
            if [[ "$line" =~ ^::[[:space:]](.*)$ ]]; then
                if [[ "${BASH_REMATCH[1]}" == "$selected_category" ]]; then
                    in_selected_category=1
                else
                    in_selected_category=0
                fi
            elif [ "$in_selected_category" -eq 1 ] && [[ "$line" =~ ^([^|]+)\|(.*)$ ]]; then
                recipe="${BASH_REMATCH[1]}"
                description="${BASH_REMATCH[2]}"
                cat_recipes+=("$recipe")
                
                if [[ -n "$description" ]]; then
                    echo "$i) $recipe - $description"
                else
                    echo "$i) $recipe"
                fi
                i=$((i+1))
            fi
        done < "$FINAL_FILE"
        
        # Prompt to select a recipe
        echo
        read -p "Select a recipe (1-${#cat_recipes[@]}, or 'q' to quit): " recipe_choice
        
        if [[ "$recipe_choice" == "q" ]]; then
            echo "Exiting without running any recipe."
            rm -rf "$TEMP_DIR"
            exit 0
        fi
        
        # Validate input
        if ! [[ "$recipe_choice" =~ ^[0-9]+$ ]] || [ "$recipe_choice" -lt 1 ] || [ "$recipe_choice" -gt "${#cat_recipes[@]}" ]; then
            echo "Invalid selection. Exiting."
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        
        selected="${cat_recipes[$((recipe_choice-1))]}"
    fi
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    # Exit if the user chose to exit or no selection was made
    if [[ -z "$selected" ]]; then
        echo "Exiting without running any recipe."
        exit 0
    fi
    
    # Extract the recipe name (remove description if present)
    selected_recipe=$(echo "$selected" | cut -d' ' -f1)
    
    # Execute the selected recipe
    echo "Running recipe: ${green}${bold}$selected_recipe${normal}"
    ujust "$selected_recipe"
