package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type recipe struct {
	name        string
	description string
}

type model struct {
	categories     []string
	recipesByCat   map[string][]recipe
	currentTab     int
	selectedRecipe int
	width          int
	height         int
}

var runRecipe string

var (
	layoutWidth    = 80
	appBorder      = lipgloss.NewStyle().Border(lipgloss.NormalBorder())
	titleStyle     = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("15"))
	catSelected    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#00afff")).Underline(true)
	catInactive    = lipgloss.NewStyle().Faint(true)
	recipeActive   = lipgloss.NewStyle().Foreground(lipgloss.Color("10")).Bold(true)
	recipeInactive = lipgloss.NewStyle().Foreground(lipgloss.Color("7"))
	descText       = lipgloss.NewStyle().Padding(1, 0)
	controlStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Italic(true)
)

func divider(width int) string {
	return strings.Repeat("─", width-4)
}

func initialModel() model {
	recipeDir := "/usr/share/ublue-os/just"
	files, _ := filepath.Glob(filepath.Join(recipeDir, "*.just"))

	categories := []string{}
	recipesByCat := make(map[string][]recipe)

	recipeRegex := regexp.MustCompile(`^\s*([a-zA-Z0-9_-]+)\s*:\s*.*`)
	commentRegex := regexp.MustCompile(`^\s*#\s*(.*)`)

	for _, file := range files {
		base := filepath.Base(file)
		if strings.Contains(base, "picker") {
			continue
		}
		category := cleanCategoryName(base)

		f, err := os.Open(file)
		if err != nil {
			continue
		}
		defer f.Close()

		scanner := bufio.NewScanner(f)
		var lastComment string
		found := false
		for scanner.Scan() {
			line := scanner.Text()

			if commentRegex.MatchString(line) {
				lastComment = commentRegex.FindStringSubmatch(line)[1]
				continue
			}

			if matches := recipeRegex.FindStringSubmatch(line); matches != nil {
				name := matches[1]
				if strings.HasPrefix(name, "_") || strings.Contains(line, "alias") || strings.Contains(line, "[private]") {
					continue
				}
				recipesByCat[category] = append(recipesByCat[category], recipe{
					name:        name,
					description: lastComment,
				})
				lastComment = ""
				found = true
			}
		}
		if found {
			categories = append(categories, category)
		}
	}

	sort.Strings(categories)

	// Get terminal width and height if possible
	cmd := exec.Command("stty", "size")
	cmd.Stdin = os.Stdin
	out, err := cmd.Output()
	width, height := layoutWidth, 24
	if err == nil {
		fmt.Sscanf(string(out), "%d %d", &height, &width)
		if width > 100 {
			width = 100 // Cap width at 100 columns
		} else if width < 60 {
			width = 60 // Minimum width of 60
		}
	}

	return model{
		categories:     categories,
		recipesByCat:   recipesByCat,
		currentTab:     0,
		selectedRecipe: 0,
		width:          width,
		height:         height,
	}
}

func cleanCategoryName(filename string) string {
	name := strings.TrimSuffix(filename, ".just")
	name = regexp.MustCompile(`^[0-9]+-`).ReplaceAllString(name, "")
	parts := strings.Split(name, "-")
	for i, part := range parts {
		if len(part) > 0 {
			parts[i] = strings.ToUpper(part[0:1]) + part[1:]
		}
	}
	return strings.Join(parts, " ")
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "left", "h":
			if m.currentTab > 0 {
				m.currentTab--
				m.selectedRecipe = 0
			}
		case "right", "l":
			if m.currentTab < len(m.categories)-1 {
				m.currentTab++
				m.selectedRecipe = 0
			}
		case "up", "k":
			if m.selectedRecipe > 0 {
				m.selectedRecipe--
			}
		case "down", "j":
			if m.selectedRecipe < len(m.currentRecipes())-1 {
				m.selectedRecipe++
			}
		case "enter":
			if len(m.currentRecipes()) > 0 {
				selected := m.currentRecipes()[m.selectedRecipe]
				runRecipe = selected.name
				return m, tea.Quit
			}
		case "esc", "q", "ctrl+c":
			return m, tea.Quit
		}
	case tea.WindowSizeMsg:
		m.width = msg.Width
		if m.width > 100 {
			m.width = 100
		} else if m.width < 60 {
			m.width = 60
		}
		m.height = msg.Height
	}
	return m, nil
}

func (m model) View() string {
	contentWidth := m.width - 4 // Account for borders
	appBorder = appBorder.Width(m.width)
	descText = descText.Width(contentWidth)

	var header strings.Builder
	header.WriteString(titleStyle.Render("Available ujust recipes") + "\n")
	header.WriteString(divider(m.width) + "\n")

	left := ""
	if m.currentTab > 0 {
		prev := m.categories[m.currentTab-1]
		left = "← " + catInactive.Render(prev)
	}
	center := catSelected.Render(m.categories[m.currentTab])
	right := ""
	if m.currentTab < len(m.categories)-1 {
		next := m.categories[m.currentTab+1]
		right = catInactive.Render(next) + " →"
	}

	// Calculate space for each section
	leftWidth := 20
	centerWidth := contentWidth - 40 // Give center the remaining space
	rightWidth := 20

	navLine := fmt.Sprintf("%-*s %-*s %*s",
		leftWidth, left,
		centerWidth, center,
		rightWidth, right)
	header.WriteString(navLine + "\n")
	header.WriteString(controlStyle.Render("← → Change Category | ↑ ↓ Navigate Recipes | Enter: Select | Esc: Exit") + "\n")
	header.WriteString(divider(m.width) + "\n")

	// Calculate max recipes to display based on terminal height
	maxRecipes := m.height - 15 // Adjust based on header and footer size
	if maxRecipes < 5 {
		maxRecipes = 5
	}

	// Display recipes with pagination if needed
	recipes := m.currentRecipes()
	displayCount := len(recipes)
	if displayCount > maxRecipes {
		displayCount = maxRecipes
	}

	// Calculate starting index for scrolling
	startIdx := 0
	if m.selectedRecipe >= displayCount {
		startIdx = m.selectedRecipe - displayCount + 1
		if startIdx+displayCount > len(recipes) {
			startIdx = len(recipes) - displayCount
		}
	}

	var recipeLines []string
	for i := 0; i < displayCount && i+startIdx < len(recipes); i++ {
		r := recipes[i+startIdx]
		line := r.name
		if i+startIdx == m.selectedRecipe {
			recipeLines = append(recipeLines, recipeActive.Render("▶ "+line))
		} else {
			recipeLines = append(recipeLines, recipeInactive.Render("  "+line))
		}
	}

	var descBlock string
	if len(recipes) > 0 {
		r := recipes[m.selectedRecipe]
		desc := "Selected: " + recipeActive.Render(r.name)
		if r.description != "" {
			desc += "\n\n" + wrap(r.description, contentWidth)
		} else {
			desc += "\n\nNo description available."
		}
		descBlock = divider(m.width) + "\n" + descText.Render(desc)
	}

	fullView := header.String() + "\n" + strings.Join(recipeLines, "\n") + "\n\n" + descBlock
	return appBorder.Render(fullView)
}

func (m model) currentRecipes() []recipe {
	if m.currentTab < 0 || m.currentTab >= len(m.categories) {
		return []recipe{}
	}
	return m.recipesByCat[m.categories[m.currentTab]]
}

func wrap(s string, limit int) string {
	words := strings.Fields(s)
	if len(words) == 0 {
		return ""
	}

	var result strings.Builder
	line := ""

	for _, word := range words {
		if len(line)+len(word)+1 > limit {
			result.WriteString(line + "\n")
			line = word
		} else {
			if line != "" {
				line += " "
			}
			line += word
		}
	}

	if line != "" {
		result.WriteString(line)
	}
	return result.String()
}

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if err := p.Start(); err != nil {
		fmt.Println("Error running program:", err)
		os.Exit(1)
	}

	if runRecipe != "" {
		fmt.Print("\033[2J\033[H") // Clear screen
		fmt.Printf("Running recipe: %s...\n\n", runRecipe)
		cmd := exec.Command("ujust", runRecipe)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		_ = cmd.Run()
	}
}
