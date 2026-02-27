#!/bin/bash

# task manager - bash assignment
# my name: moamen lotfy

TASKS_FILE="tasks.txt"

# colors i found online
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# create file if not there
if [ ! -f "$TASKS_FILE" ]; then
    touch "$TASKS_FILE"
fi

####################################
# helper functions
####################################

get_next_id(){
    if [ ! -s "$TASKS_FILE" ]; then
        echo 1
        return
    fi
    # get max id then add 1
    max=$(cut -d"|" -f1 "$TASKS_FILE" | sort -n | tail -1)
    echo $(( max + 1 ))
}

check_id_exists(){
    grep -q "^$1|" "$TASKS_FILE"
}

valid_priority(){
    [ "$1" = "high" ] || [ "$1" = "medium" ] || [ "$1" = "low" ]
}

valid_status(){
    [ "$1" = "pending" ] || [ "$1" = "in-progress" ] || [ "$1" = "done" ]
}

valid_date(){
    # check format first
    echo "$1" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" || return 1
    date -d "$1" &>/dev/null
}

# print the table header line
table_header(){
    echo "--------------------------------------------------------------"
    printf "%-4s  %-22s  %-8s  %-11s  %-11s\n" "ID" "Title" "Priority" "Due Date" "Status"
    echo "--------------------------------------------------------------"
}

# print single task row with colors
print_task(){
    local id=$1 title=$2 pri=$3 due=$4 stat=$5

    # trim title
    if [ ${#title} -gt 20 ]; then
        title="${title:0:18}.."
    fi

    # pick color for priority
    local pc=$NC
    [ "$pri" = "high" ]   && pc=$RED
    [ "$pri" = "medium" ] && pc=$YELLOW
    [ "$pri" = "low" ]    && pc=$GREEN

    # pick color for status
    local sc=$NC
    [ "$stat" = "done" ]        && sc=$GREEN
    [ "$stat" = "in-progress" ] && sc=$CYAN
    [ "$stat" = "pending" ]     && sc=$YELLOW

    printf "%-4s  %-22s  ${pc}%-8s${NC}  %-11s  ${sc}%-11s${NC}\n" \
        "$id" "$title" "$pri" "$due" "$stat"
}

press_enter(){
    echo ""
    read -p "press enter..."
}

####################################
# 1. Add task
####################################
add_task(){
    echo ""
    echo "== Add Task =="

    # title - cant be empty
    local title=""
    while [ -z "$title" ]; do
        read -p "title: " title
        [ -z "$title" ] && echo -e "${RED}title is required${NC}"
    done

    # priority
    local pri=""
    while ! valid_priority "$pri"; do
        read -p "priority (high/medium/low): " pri
        valid_priority "$pri" || echo -e "${RED}wrong, try again${NC}"
    done

    # due date
    local due=""
    while ! valid_date "$due" 2>/dev/null; do
        read -p "due date (YYYY-MM-DD): " due
        valid_date "$due" 2>/dev/null || echo -e "${RED}bad date format${NC}"
    done

    local id=$(get_next_id)
    echo "$id|$title|$pri|$due|pending" >> "$TASKS_FILE"

    echo -e "${GREEN}task added with id=$id${NC}"
}

####################################
# 2. List tasks
####################################
list_tasks(){
    echo ""
    echo "== List Tasks =="
    echo "1) all"
    echo "2) filter by status"
    echo "3) filter by priority"
    read -p "> " ch

    local fcol="" fval=""

    if [ "$ch" = "2" ]; then
        read -p "status (pending/in-progress/done): " fval
        fcol="status"
    elif [ "$ch" = "3" ]; then
        read -p "priority (high/medium/low): " fval
        fcol="priority"
    fi

    echo ""
    table_header

    local cnt=0
    while IFS="|" read -r id title pri due stat; do
        # filter logic
        if [ "$fcol" = "status" ]   && [ "$stat" != "$fval" ]; then continue; fi
        if [ "$fcol" = "priority" ] && [ "$pri"  != "$fval" ]; then continue; fi

        print_task "$id" "$title" "$pri" "$due" "$stat"
        cnt=$(( cnt + 1 ))
    done < "$TASKS_FILE"

    echo "--------------------------------------------------------------"
    echo "total: $cnt"
}

####################################
# 3. Update task
####################################
update_task(){
    echo ""
    echo "== Update Task =="
    read -p "enter id: " tid

    if ! check_id_exists "$tid"; then
        echo -e "${RED}id $tid not found${NC}"
        return
    fi

    # get current values
    local line=$(grep "^$tid|" "$TASKS_FILE")
    IFS="|" read -r cid ctitle cpri cdue cstat <<< "$line"

    echo ""
    echo "current:"
    table_header
    print_task "$cid" "$ctitle" "$cpri" "$cdue" "$cstat"
    echo ""

    # new title
    read -p "new title [$ctitle]: " ntitle
    [ -z "$ntitle" ] && ntitle="$ctitle"

    # new priority
    read -p "new priority [$cpri]: " npri
    if [ -z "$npri" ]; then
        npri="$cpri"
    elif ! valid_priority "$npri"; then
        echo -e "${YELLOW}keeping old priority${NC}"
        npri="$cpri"
    fi

    # new due date
    read -p "new due date [$cdue]: " ndue
    if [ -z "$ndue" ]; then
        ndue="$cdue"
    elif ! valid_date "$ndue" 2>/dev/null; then
        echo -e "${YELLOW}bad date, keeping old one${NC}"
        ndue="$cdue"
    fi

    # new status
    read -p "new status [$cstat]: " nstat
    if [ -z "$nstat" ]; then
        nstat="$cstat"
    elif ! valid_status "$nstat"; then
        echo -e "${YELLOW}invalid status, keeping old one${NC}"
        nstat="$cstat"
    fi

    # replace the line using sed
    local newline="$tid|$ntitle|$npri|$ndue|$nstat"
    local escaped=$(printf '%s\n' "$newline" | sed 's/[[\.*^$()+?{|]/\\&/g')
    sed -i "s|^$tid|.*|$escaped|" "$TASKS_FILE"

    echo -e "${GREEN}updated!${NC}"
}

####################################
# 4. Delete task
####################################
delete_task(){
    echo ""
    echo "== Delete Task =="
    read -p "enter id: " tid

    if ! check_id_exists "$tid"; then
        echo -e "${RED}id $tid doesnt exist${NC}"
        return
    fi

    # show task before deleting
    local line=$(grep "^$tid|" "$TASKS_FILE")
    IFS="|" read -r d_id d_title d_pri d_due d_stat <<< "$line"

    echo ""
    table_header
    print_task "$d_id" "$d_title" "$d_pri" "$d_due" "$d_stat"
    echo ""

    read -p "delete this? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        grep -v "^$tid|" "$TASKS_FILE" > /tmp/tasks_tmp.txt
        mv /tmp/tasks_tmp.txt "$TASKS_FILE"
        echo -e "${GREEN}done, task deleted${NC}"
    else
        echo "ok cancelled"
    fi
}

####################################
# 5. Search by title
####################################
search_tasks(){
    echo ""
    echo "== Search =="
    read -p "keyword: " kw

    if [ -z "$kw" ]; then
        echo -e "${RED}enter a keyword${NC}"
        return
    fi

    echo ""
    table_header

    local cnt=0
    while IFS="|" read -r id title pri due stat; do
        # case insensitive search
        if echo "$title" | grep -qi "$kw"; then
            print_task "$id" "$title" "$pri" "$due" "$stat"
            cnt=$(( cnt + 1 ))
        fi
    done < "$TASKS_FILE"

    echo "--------------------------------------------------------------"
    echo "found: $cnt"
}

####################################
# reports
####################################

# summary - count by status
summary_report(){
    echo ""
    echo "== Summary =="

    local p=0 ip=0 d=0
    while IFS="|" read -r id title pri due stat; do
        case "$stat" in
            pending)     p=$(( p + 1 ))  ;;
            in-progress) ip=$(( ip + 1 )) ;;
            done)        d=$(( d + 1 ))  ;;
        esac
    done < "$TASKS_FILE"

    local total=$(( p + ip + d ))
    echo -e "${YELLOW}pending:${NC}      $p"
    echo -e "${CYAN}in-progress:${NC}  $ip"
    echo -e "${GREEN}done:${NC}         $d"
    echo "-------------------"
    echo "total:        $total"
}

# overdue - not done and date passed
overdue_report(){
    echo ""
    echo "== Overdue Tasks =="

    local today=$(date +%Y-%m-%d)
    local cnt=0

    table_header
    while IFS="|" read -r id title pri due stat; do
        [ "$stat" = "done" ] && continue
        # string compare works fine for YYYY-MM-DD
        if [[ "$due" < "$today" ]]; then
            print_task "$id" "$title" "$pri" "$due" "$stat"
            cnt=$(( cnt + 1 ))
        fi
    done < "$TASKS_FILE"

    echo "--------------------------------------------------------------"
    if [ $cnt -eq 0 ]; then
        echo -e "${GREEN}no overdue tasks!${NC}"
    else
        echo -e "${RED}$cnt overdue${NC}"
    fi
}

# group by priority
priority_report(){
    echo ""
    echo "== By Priority =="

    for p in high medium low; do
        echo ""
        echo "[ $p ]"
        printf "%-4s  %-22s  %-11s  %-11s\n" "ID" "Title" "Due Date" "Status"
        echo "------------------------------------------------"

        local cnt=0
        while IFS="|" read -r id title pri due stat; do
            if [ "$pri" = "$p" ]; then
                [ ${#title} -gt 20 ] && title="${title:0:18}.."
                printf "%-4s  %-22s  %-11s  %-11s\n" "$id" "$title" "$due" "$stat"
                cnt=$(( cnt + 1 ))
            fi
        done < "$TASKS_FILE"

        [ $cnt -eq 0 ] && echo "  (none)"
    done
}

####################################
# bonus: export csv
####################################
export_csv(){
    echo ""
    echo "== Export CSV =="

    local fname="tasks_export_$(date +%Y%m%d).csv"
    echo "ID,Title,Priority,Due Date,Status" > "$fname"

    while IFS="|" read -r id title pri due stat; do
        echo "$id,\"$title\",$pri,$due,$stat" >> "$fname"
    done < "$TASKS_FILE"

    echo -e "${GREEN}exported to $fname${NC}"
}

####################################
# bonus: sort
####################################
sort_tasks(){
    echo ""
    echo "== Sort =="
    echo "1) by due date"
    echo "2) by priority (high first)"
    read -p "> " opt

    echo ""
    table_header

    if [ "$opt" = "1" ]; then
        sort -t"|" -k4 "$TASKS_FILE" | while IFS="|" read -r id title pri due stat; do
            print_task "$id" "$title" "$pri" "$due" "$stat"
        done

    elif [ "$opt" = "2" ]; then
        for p in high medium low; do
            while IFS="|" read -r id title pri due stat; do
                [ "$pri" = "$p" ] && print_task "$id" "$title" "$pri" "$due" "$stat"
            done < "$TASKS_FILE"
        done
    else
        echo "invalid"
    fi
}

####################################
# reports submenu
####################################
reports_menu(){
    while true; do
        echo ""
        echo "== Reports =="
        echo "1) summary"
        echo "2) overdue"
        echo "3) by priority"
        echo "0) back"
        read -p "> " opt

        case $opt in
            1) summary_report ;;
            2) overdue_report ;;
            3) priority_report ;;
            0) return ;;
            *) echo "invalid" ;;
        esac

        press_enter
    done
}

####################################
# main menu
####################################
main_menu(){
    while true; do
        clear
        echo "=============================="
        echo "      task manager            "
        echo "=============================="
        echo "1) add task"
        echo "2) list tasks"
        echo "3) update task"
        echo "4) delete task"
        echo "5) search"
        echo "6) reports"
        echo "7) export csv"
        echo "8) sort"
        echo "0) exit"
        echo "=============================="
        read -p "> " choice

        case $choice in
            1) add_task    ;;
            2) list_tasks  ;;
            3) update_task ;;
            4) delete_task ;;
            5) search_tasks ;;
            6) reports_menu ;;
            7) export_csv  ;;
            8) sort_tasks  ;;
            0) echo "bye" ; exit 0 ;;
            *) echo "wrong choice" ;;
        esac

        press_enter
    done
}

# start
main_menu
