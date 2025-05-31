# vim: set ft=make :

# Interactive picker for ujust recipes
pick:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    # Clear the screen for a clean display
    clear
    
    # Define constants
    WINDOW_WIDTH=75  # Total width of the UI window (inside borders)
    BOX_WIDTH=$((WINDOW_WIDTH))  # Width for border lines
    
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
    
    # Helper function to truncate text to fit within a specific width
    truncate_text() {
        local text="$1"
        local max_width="$2"
        
        if [ ${#text} -gt $max_width ]; then
            echo "${text:0:$((max_width-3))}..."
        else
            echo "$text"
        fi
    }
    
    # Function to create a horizontal border line
    create_border() {
        local char="$1"
        printf "%s%${BOX_WIDTH}s%s\n" "│" "" "│" | tr ' ' "$char"
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
    
    # Create the final formatted file for display
    FINAL_FILE="${TEMP_DIR}/recipes.txt"
    touch "$FINAL_FILE"
    
    # Combine all category files into the final file
    for cat_file in "${TEMP_DIR}"/*.just; do
        if [[ -f "$cat_file" ]]; then
            cat "$cat_file" >> "$FINAL_FILE"
            echo "" >> "$FINAL_FILE"  # Add a blank line between categories
        fi
    done
    
    # Extract categories and recipes
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
    
    # Check if any categories were found
    if [ ${#categories[@]} -eq 0 ]; then
        echo "No categories/recipes found. Exiting."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Setup initial state
    current_tab=0
    current_recipe=0
    
    # Function to draw tabs
    draw_tabs() {
        local tab_index=$1
        
        # Calculate max tab width to ensure all tabs fit
        local separator_space=3  # Space taken by " | "
        local total_separator_space=$(( (${#categories[@]} - 1) * separator_space ))
        local max_tab_width=$(( (WINDOW_WIDTH - total_separator_space - 4) / ${#categories[@]} ))
        if [ $max_tab_width -lt 3 ]; then
            max_tab_width=3  # Minimum width to avoid empty tabs
        fi
        
        # Draw top border with correct width
        echo "┌$(printf '─%.0s' $(seq 1 $BOX_WIDTH))┐"
        
        # Tab line with proper padding
        echo -n "│ "
        
        for i in "${!categories[@]}"; do
            local tab_text="${categories[$i]}"
            
            # Truncate if necessary
            if [ ${#tab_text} -gt $max_tab_width ]; then
                tab_text="${tab_text:0:$((max_tab_width-3))}..."
            fi
            
            if [ $i -eq $tab_index ]; then
                echo -ne "${green}${bold}${tab_text}${normal}"
            else
                echo -n "$tab_text"
            fi
            
            # Add separator between tabs
            if [ $i -lt $((${#categories[@]} - 1)) ]; then
                echo -n " | "
            fi
        done
        
        # Calculate padding to reach right edge
        local current_pos=$(echo -n "│ " | wc -c)
        for i in "${!categories[@]}"; do
            local tab_text="${categories[$i]}"
            if [ ${#tab_text} -gt $max_tab_width ]; then
                current_pos=$((current_pos + max_tab_width))
            else
                current_pos=$((current_pos + ${#tab_text}))
            fi
            
            # Add separator length
            if [ $i -lt $((${#categories[@]} - 1)) ]; then
                current_pos=$((current_pos + 3))  # " | " = 3 chars
            fi
        done
        
        # Add padding to right edge
        local padding=$((BOX_WIDTH + 2 - current_pos))
        printf "%${padding}s│\n" ""
        
        # Tab navigation hint
        echo "├$(printf '─%.0s' $(seq 1 $BOX_WIDTH))┤"
        printf "│ %-${BOX_WIDTH}s │\n" "← → Change Category | ↑ ↓ Navigate Recipes | Enter: Select | Esc: Exit"
        echo "├$(printf '─%.0s' $(seq 1 $BOX_WIDTH))┤"
    }
    
    # Function to display recipes
    display_recipes() {
        local tab_index=$1
        local recipe_index=$2
        local cat_file="${category_files[$tab_index]}"
        local recipes=()
        local content_width=$((BOX_WIDTH - 2))  # Available width for content
        
        # Read recipes into array
        while IFS= read -r line; do
            recipes+=("$line")
        done < "$cat_file"
        
        # Display recipes with proper alignment
        for i in "${!recipes[@]}"; do
            local recipe_text="${recipes[$i]}"
            local prefix_length=3  # "│   " = 4 chars
            
            if [ $i -eq $recipe_index ]; then
                prefix_length=5  # "│ ▶ " = 6 chars (arrow takes 2 visual spaces)
                
                # Truncate if necessary to fit in box
                if [ ${#recipe_text} -gt $((content_width - prefix_length)) ]; then
                    recipe_text="${recipe_text:0:$((content_width-prefix_length-3))}..."
                fi
                
                # Print with precise padding to match right border
                printf "│ ${cyan}${bold}▶ %-$((content_width-prefix_length+1))s${normal}│\n" "$recipe_text"
            else
                # Truncate if necessary to fit in box
                if [ ${#recipe_text} -gt $((content_width - prefix_length)) ]; then
                    recipe_text="${recipe_text:0:$((content_width-prefix_length-3))}..."
                fi
                
                # Print with precise padding to match right border
                printf "│   %-$((content_width-prefix_length+1))s│\n" "$recipe_text"
            fi
        done
        
        # Add padding if there are few recipes
        local min_lines=10
        if [ ${#recipes[@]} -lt $min_lines ]; then
            for ((i=${#recipes[@]}; i<$min_lines; i++)); do
                printf "│%-${BOX_WIDTH}s│\n" ""
            done
        fi
        
        # Bottom border
        echo "└$(printf '─%.0s' $(seq 1 $BOX_WIDTH))┘"
    }
    
    # Main UI Loop
    while true; do
        clear
        
        # Get recipes from current category
        mapfile -t recipes < "${category_files[$current_tab]}"
        
        # Ensure current_recipe is in bounds
        if [ ${#recipes[@]} -gt 0 ]; then
            if [ $current_recipe -lt 0 ]; then
                current_recipe=0
            fi
            
            if [ $current_recipe -ge ${#recipes[@]} ]; then
                current_recipe=$((${#recipes[@]} - 1))
            fi
        else
            current_recipe=0
        fi
        
        # Draw UI
        draw_tabs "$current_tab"
        display_recipes "$current_tab" "$current_recipe"
        
        # Get keystroke
        read -s -n 1 key
        
        if [[ "$key" == $'\e' ]]; then
            read -s -n 2 -t 0.1 arrow
            
            if [[ "$arrow" == "[A" ]]; then  # Up arrow
                current_recipe=$((current_recipe - 1))
                if [ $current_recipe -lt 0 ]; then
                    current_recipe=0
                fi
            elif [[ "$arrow" == "[B" ]]; then  # Down arrow
                current_recipe=$((current_recipe + 1))
                if [ $current_recipe -ge ${#recipes[@]} ]; then
                    current_recipe=$((${#recipes[@]} - 1))
                fi
            elif [[ "$arrow" == "[C" ]]; then  # Right arrow
                current_tab=$((current_tab + 1))
                if [ $current_tab -ge ${#categories[@]} ]; then
                    current_tab=0
                fi
                current_recipe=0
            elif [[ "$arrow" == "[D" ]]; then  # Left arrow
                current_tab=$((current_tab - 1))
                if [ $current_tab -lt 0 ]; then
                    current_tab=$((${#categories[@]} - 1))
                fi
                current_recipe=0
            else
                # Escape key pressed (not followed by arrow sequence)
                echo "Exiting without running any recipe."
                rm -rf "$TEMP_DIR"
                exit 0
            fi
        elif [[ "$key" == "" ]]; then  # Enter key
            if [ ${#recipes[@]} -gt 0 ]; then
                selected="${recipes[$current_recipe]}"
                # Extract recipe name (remove description if present)
                selected_recipe=$(echo "$selected" | awk '{print $1}')
                break
            fi
        fi
    done
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    # Exit if the user chose to exit or no selection was made
    if [[ -z "$selected_recipe" ]]; then
        echo "Exiting without running any recipe."
        exit 0
    fi
    
    # Execute the selected recipe
    echo "Running recipe: ${green}${bold}$selected_recipe${normal}"
    ujust "$selected_recipe"
