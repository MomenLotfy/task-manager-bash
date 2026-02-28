#!/usr/bin/env bash
# =============================================================================
# Mini Task Manager - Bash Project by Moamen Lotfy
# =============================================================================

TASKS_FILE="tasks.txt"
DELIMITER="|"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ----------------------
# Utility Functions
# ----------------------
next_id() {
    if [[ ! -f $TASKS_FILE ]] || [[ ! -s $TASKS_FILE ]]; then
        echo 1
    else
        tail -n 1 "$TASKS_FILE" | cut -d"$DELIMITER" -f1 | awk '{print $1+1}'
    fi
}

validate_date() {
    if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 0
    else
        echo -e "${RED}Invalid date format! Use YYYY-MM-DD.${NC}"
        return 1
    fi
}

validate_priority() {
    case $1 in
        high|medium|low) return 0 ;;
        *) echo -e "${RED}Priority must be high, medium, or low.${NC}"; return 1 ;;
    esac
}

id_exists() {
    grep -q "^$1$DELIMITER" "$TASKS_FILE" 2>/dev/null
    return $?
}

# ----------------------
# Core Functions
# ----------------------

add_task() {
    echo -e "${CYAN}--- Add New Task ---${NC}"
    read -p "Enter task title: " title
    [[ -z "$title" ]] && { echo -e "${RED}Title cannot be empty!${NC}"; return; }

    read -p "Enter priority (high/medium/low): " priority
    validate_priority "$priority" || return

    read -p "Enter due date (YYYY-MM-DD): " due
    validate_date "$due" || return

    id=$(next_id)
    status="pending"

    echo "$id$DELIMITER$title$DELIMITER$priority$DELIMITER$due$DELIMITER$status" >> "$TASKS_FILE"
    echo -e "${GREEN}Task added successfully!${NC}"
}

# Function to color-code status
status_color() {
    case $1 in
        pending) echo -e "${YELLOW}$1${NC}" ;;
        "in-progress") echo -e "${BLUE}$1${NC}" ;;
        done) echo -e "${GREEN}$1${NC}" ;;
        *) echo "$1" ;;
    esac
}

# Function to color-code priority
priority_color() {
    case $1 in
        high) echo -e "${RED}$1${NC}" ;;
        medium) echo -e "${YELLOW}$1${NC}" ;;
        low) echo -e "${GREEN}$1${NC}" ;;
        *) echo "$1" ;;
    esac
}

# Function to highlight overdue dates
date_color() {
    today=$(date +%Y-%m-%d)
    if [[ "$1" < "$today" ]]; then
        echo -e "${RED}$1${NC}"
    else
        echo "$1"
    fi
}

list_tasks() {
    echo -e "${CYAN}--- Task List ---${NC}"
    [[ ! -f $TASKS_FILE ]] || [[ ! -s $TASKS_FILE ]] || awk -F"$DELIMITER" 'BEGIN{printf "%-3s | %-20s | %-10s | %-12s | %-12s\n","ID","Title","Priority","Due Date","Status"} {printf "%-3s | %-20s | %-10s | %-12s | %-12s\n",$1,$2,$3,$4,$5}' "$TASKS_FILE"

    while IFS="$DELIMITER" read -r id title priority due status; do
        p=$(priority_color "$priority")
        s=$(status_color "$status")
        d=$(date_color "$due")
        printf "%-3s | %-20s | %-10b | %-12b | %-12b\n" "$id" "$title" "$p" "$d" "$s"
    done < "$TASKS_FILE"

    # Sorting option
    echo -e "\nDo you want to sort tasks? (1) By Date (2) By Priority (3) No"
    read -p "Choose: " sort_choice
    case $sort_choice in
        1)
            echo -e "${CYAN}--- Tasks Sorted by Due Date ---${NC}"
            sort -t"$DELIMITER" -k4 "$TASKS_FILE" | while IFS="$DELIMITER" read -r id title priority due status; do
                printf "%-3s | %-20s | %-10b | %-12b | %-12b\n" "$id" "$title" "$(priority_color "$priority")" "$(date_color "$due")" "$(status_color "$status")"
            done
            ;;
        2)
            echo -e "${CYAN}--- Tasks Sorted by Priority ---${NC}"
            sort -t"$DELIMITER" -k3 "$TASKS_FILE" | while IFS="$DELIMITER" read -r id title priority due status; do
                printf "%-3s | %-20s | %-10b | %-12b | %-12b\n" "$id" "$title" "$(priority_color "$priority")" "$(date_color "$due")" "$(status_color "$status")"
            done
            ;;
        3) ;;
        *) echo -e "${RED}Invalid choice.${NC}" ;;
    esac
}

update_task() {
    echo -e "${CYAN}--- Update Task ---${NC}"
    read -p "Enter task ID to update: " id
    id_exists "$id" || { echo -e "${RED}ID not found!${NC}"; return; }

    task=$(grep "^$id$DELIMITER" "$TASKS_FILE")
    IFS="$DELIMITER" read -r _title _priority _due _status <<< "$(echo "$task" | cut -d"$DELIMITER" -f2-5)"

    read -p "Enter new title ($_title): " title
    title=${title:-$_title}

    read -p "Enter new priority ($_priority): " priority
    priority=${priority:-$_priority}
    validate_priority "$priority" || return

    read -p "Enter new due date ($_due): " due
    due=${due:-$_due}
    validate_date "$due" || return

    read -p "Enter new status ($_status) [pending/in-progress/done]: " status
    status=${status:-$_status}

    sed -i "/^$id$DELIMITER/c\\$id$DELIMITER$title$DELIMITER$priority$DELIMITER$due$DELIMITER$status" "$TASKS_FILE"
    echo -e "${GREEN}Task updated successfully!${NC}"
}

delete_task() {
    echo -e "${CYAN}--- Delete Task ---${NC}"
    read -p "Enter task ID to delete: " id
    id_exists "$id" || { echo -e "${RED}ID not found!${NC}"; return; }

    read -p "Are you sure you want to delete task $id? (y/n): " confirm
    [[ $confirm == "y" ]] && sed -i "/^$id$DELIMITER/d" "$TASKS_FILE" && echo -e "${GREEN}Task deleted.${NC}" || echo "Deletion cancelled."
}

search_tasks() {
    echo -e "${CYAN}--- Search Tasks ---${NC}"
    read -p "Enter keyword or regex to search in titles: " keyword
    grep -i -E "$keyword" "$TASKS_FILE" | while IFS="$DELIMITER" read -r id title priority due status; do
        printf "%-3s | %-20s | %-10b | %-12b | %-12b\n" "$id" "$title" "$(priority_color "$priority")" "$(date_color "$due")" "$(status_color "$status")"
    done
}

reports() {
    echo -e "${CYAN}--- Reports ---${NC}"
    echo "1) Task Summary"
    echo "2) Overdue Tasks"
    echo "3) Priority Report"
    echo "4) Export to CSV"
    read -p "Choose report: " choice

    case $choice in
        1)
            echo -e "${YELLOW}--- Task Summary ---${NC}"
            awk -F"$DELIMITER" '{count[$5]++} END {for(s in count) print s ": " count[s]}' "$TASKS_FILE"
            ;;
        2)
            echo -e "${YELLOW}--- Overdue Tasks ---${NC}"
            today=$(date +%Y-%m-%d)
            awk -F"$DELIMITER" -v today="$today" '$4 < today && $5 != "done"' "$TASKS_FILE" | while IFS="$DELIMITER" read -r id title priority due status; do
                printf "%-3s | %-20s | %-10b | %-12b | %-12b\n" "$id" "$title" "$(priority_color "$priority")" "$(date_color "$due")" "$(status_color "$status")"
            done
            ;;
        3)
            echo -e "${YELLOW}--- Tasks by Priority ---${NC}"
            sort -t"$DELIMITER" -k3 "$TASKS_FILE" | while IFS="$DELIMITER" read -r id title priority due status; do
                printf "%-3s | %-20s | %-10b | %-12b | %-12b\n" "$id" "$title" "$(priority_color "$priority")" "$(date_color "$due")" "$(status_color "$status")"
            done
            ;;
        4)
            cp "$TASKS_FILE" tasks.csv
            echo -e "${GREEN}Tasks exported to tasks.csv successfully!${NC}"
            ;;
        *)
            echo -e "${RED}Invalid report choice.${NC}"
            ;;
    esac
}

# ----------------------
# Main Menu
# ----------------------
while true; do
    echo -e "\n${MAGENTA}--- Mini Task Manager ---${NC}"
    echo "1) Add Task"
    echo "2) List Tasks"
    echo "3) Update Task"
    echo "4) Delete Task"
    echo "5) Search Tasks"
    echo "6) Reports / Export"
    echo "7) Exit"
    read -p "Choose an option: " choice

    case $choice in
        1) add_task ;;
        2) list_tasks ;;
        3) update_task ;;
        4) delete_task ;;
        5) search_tasks ;;
        6) reports ;;
        7) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option. Try again.${NC}" ;;
    esac
done
