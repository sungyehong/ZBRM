#!/bin/sh
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
# 
# ZFS Appliance Usage v0.8
# 
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# Default inventory 파일
INVENTORY_FILE=./zfsa.ini

# ZFSA Login String Prefix
ZFSA_LOGINSTR_PREFIX=LOGINSTRING_
# LOGINSTRING_1=root@192.168.56.151
# LOGINSTRING_2=root@192.168.56.152

# SSH Connection timeout
SSH_TIMEOUT=3

# Dictionary 데이터 구조 생성
if [[ $SHELL == "/bin/ksh" ]]; then 
    typeset -A ZFSA_INVENTORY
    typeset -A ZFSA_USAGE
else 
    declare -A ZFSA_INVENTORY
    declare -A ZFSA_USAGE
fi

# ZFS Appliance 현황 정보를 딕셔너리 구조의 문자열로 리턴
# Parameter:
#   $1: User ID
#   $2: Hostname or IP address
#   $3: ZFSA Name 
#   $4: Location (optional)
get_zfsa_usage() {
    zfsa_script="
    script
    {
        // 용량 단위 환산을 위한 상수
        const TB = 1000000000000;
        const GB = 1000000000;
        const MB = 1000000;
        const KB = 1000;
        // 용량 출력시 소수점 이하 자리 수(0=>소수점이하 절삭, 2=>1자리...)
        const DECIMAL_POINT = 2; 

        // 풀, 프로젝트 어레이 변수
        var zfsa_pools = [];
        var zfsa_projects = [];
        var zfsa_pool_projects = [];

        // 용량 문자열을 바이트 정수로 변환
        function change2byte(data) {
            if (data[data.length - 1] == 'K') {
                data = data.slice(0, data.length - 1) * KB;
            }
            else if (data[data.length - 1] == 'M') {
                data = data.slice(0, data.length - 1) * MB;
            }
            else if (data[data.length - 1] == 'G') {
                data = data.slice(0, data.length - 1) * GB;
            }
            else if (data[data.length - 1] == 'T') {
                data = data.slice(0, data.length - 1) * TB;
            }

            return data;
        }

        // 용량 값을 문자열로 변환
        // 소수점이하 자리수는 decimal로 조정(0=>소수점이하 절삭, 2=>1자리...) 
        function number2str(num, decimal) {
            // 데이터가 없으면 ' ' 값 리턴
            if (num == undefined) {
                return ' ';
            }

            if (num >= TB) {
                tostr = parseFloat(num / TB).toString();
                tostr = tostr.slice(0, tostr.indexOf('.')+decimal) + 'TB';
            }
            else if (num >= GB) {
                tostr = parseFloat(num / GB).toString();
                tostr = tostr.slice(0, tostr.indexOf('.')+decimal) + 'GB';
            }
            else if (num >= MB) {
                tostr = parseFloat(num / MB).toString();
                tostr = tostr.slice(0, tostr.indexOf('.')+decimal) + 'MB';
            }
            else if (num >= KB) {
                tostr = parseFloat(num / KB).toString();
                tostr = tostr.slice(0, tostr.indexOf('.')+decimal) + 'KB';
            }
            else {
                tostr = num + 'B';
            }
            return tostr;
        }

        // 어레이 항목 중복제거
        function remove_duplicates(arr) {
            unique = [];
            
            for (i = 0; i < arr.length; i++) {
                if (unique.indexOf(arr[i]) === -1) {
                    unique.push(arr[i]);
                }
            }
            return unique;
        }

        // ZFSA Controller 전체 풀 리스트 딕셔너리 문자열로 출력
        function get_pool() {
            run('cd /');
            run('status');
            run('storage');

            zfsa_pools = list();

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.pools]=\"';
            ret_str = ret_str + zfsa_pools.toString();
            ret_str = ret_str + '\"';

            fmt = '%-'+ret_str.length+'s';
            // 쉘 스크립에서 출력 문자열을 환경 변수로 변경해 사용
            printf(fmt, ret_str); print('');
        } 

        // ZFSA Controller 전체 프로젝트와 풀 프로젝트 딕셔너리 생성
        // 전체 프로젝트: ZFSA_USAGE=[ZFSACTL.projects]
        // 풀 프로젝트: ZFSA_USAGE=[ZFSACTL.pool.projects]
        function get_project() {
            run('cd /');
            run('shares');
           
            // 전체 풀 리스트
            // zfsa_pools = choices('pool').sort();

            // default를 제외한 프로젝트 리스트
            for (i=0; i<zfsa_pools.length; i++) {
                pool_name = zfsa_pools[i];

                set('pool', pool_name);
                zfsa_pool_projects = list().sort();

                // default project 제외
                zfsa_pool_projects.splice(zfsa_pool_projects.indexOf('default'));

                ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.projects]=\"';
                ret_str = ret_str + zfsa_pool_projects.toString();
                ret_str = ret_str + '\"';

                // 풀 프로젝트 리스트를 출력
                fmt = '%-'+ret_str.length+'s';
                printf(fmt, ret_str); print('');

                // Pool의 프로젝트 항목 합치고
                zfsa_projects = zfsa_projects.concat(zfsa_pool_projects);
            }

            // 중복된 프로젝트 항목 제거하고
            zfsa_projects = remove_duplicates(zfsa_projects);

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.projects]=\"';
            ret_str = ret_str + zfsa_projects.toString();
            ret_str = ret_str + '\"';

            // 전체 프로젝트 리스트를 출력
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');
        }

        // ZFSA 스토리지 풀 사용 현황 
        // used, avail, total 용량을 바이트 단위로 출력
        function get_usage_by_pool(pool_name) {
            run('cd /');
            run('shares');
            set('pool', pool_name);

            ptotal = change2byte(run('get capacity').split(/\s+/)[3]);
            usage_data = change2byte(run('get usage_data').split(/\s+/)[3]);
            usage_snapshots = change2byte(run('get usage_snapshots').split(/\s+/)[3]);
            usage_replication = change2byte(run('get usage_replication').split(/\s+/)[3]);
            usage_total = change2byte(run('get usage_total').split(/\s+/)[3]);
            pavail = change2byte(run('get space_available').split(/\s+/)[3]);

            // Pool usage를 dictionary 구조의 문자열로 출력
            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.ptotal]='+parseFloat(ptotal).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.usage_data]='+parseFloat(usage_data).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.usage_snapshots]='+parseFloat(usage_snapshots).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.usage_replication]='+parseFloat(usage_replication).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.usage_total]='+parseFloat(usage_total).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.pavail]='+parseFloat(pavail).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');
        } 

        // ZFSA 스토리지 프로젝트 사용 현황
        function get_usage_by_project(pool_name, project_name) {
            run('cd /');
            run('shares');
            set('pool', pool_name);
            pool_projects = list();

            // Project가 pool에 존재하면 바이트로 변환후 할당
            if (pool_projects.indexOf(project_name) != -1) {
                run('select ' + project_name);

                used_data = change2byte(run('get space_data').split(/\s+/)[3]);
                used_snapshot = change2byte(run('get space_snapshots').split(/\s+/)[3]);
                used_total = change2byte(run('get space_total').split(/\s+/)[3]); 

                run('cd ..');
            } else { // Project가 pool에 존재하지 않으면 
                used_data = -1;
                used_snapshot = -1;
                used_total = -1; 
            }

            // Project usage를 dictionary 구조의 문자열로 출력
            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.'+project_name+'.used_data]='+used_data.toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.'+project_name+'.used_snapshot]='+used_snapshot.toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL_STR+'.'+pool_name+'.'+project_name+'.'+'used_total]='+used_total.toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');
        } 

        // Main 
        try {
            // Location 설정이 없으면
            if ('${4}' == ''){
                ZFSA_CTL_STR='${3}';
            }
            else {
                ZFSA_CTL_STR='${4}'+'.'+'${3}';
            }

            // get_hardware();
            get_pool();
            get_project();

            for (i=0; i<zfsa_pools.length; i++) {
                get_usage_by_pool(zfsa_pools[i]);
            }

            for (i=0; i<zfsa_pools.length; i++) {
                for (j=0; j<zfsa_projects.length; j++) { 
                    get_usage_by_project(zfsa_pools[i], zfsa_projects[j]);
                }
            }
        } catch (err) {
            print(err);
        }
    }"
    ret_val=$(echo "$zfsa_script" | ssh -T -o ConnectTimeout=${SSH_TIMEOUT} "${1}@${2}" | grep -v Last)

    echo "$ret_val"
}

#  __  _   _          _                                               
#   / |_) |_) |\/|   |_)  _   _  _      ._ _  _    | |  _  _.  _   _  
#  /_ |_) | \ |  |   | \ (/_ _> (_) |_| | (_ (/_   |_| _> (_| (_| (/_ 
#                                                              _|     
# ZFSA_INVENTORY
#     - LOC: "Main, DR"
#     - Main.desc: 
#     - Main.zfsa: "ZFSACTL1, ZFSACTL2"
#     - Main.ZFSACTL1: Connection string

show_zfsa_list_by_loc() {
    locations=($(echo "${ZFSA_INVENTORY[LOC]}" | tr "," " "))

    tbl_row_width=80
    BD "=" ${tbl_row_width} 
    TR "%s -a C -w ${tbl_row_width} -l | -r | -c "
    TR "%s -fc GREEN; ZFS Backup Appliance Status;%s -fc NORMAL;"; TR
    TR " "; TR; TR " "; TR
    TR "%s -w 14 ; ;%s -w 10 -a C;CTL;#POOL;#PROJECT;   TOTAL;   USED;%s -w 16;AVAIL"; TR

    BD "=" ${tbl_row_width} 
    for location in ${locations[@]}; do
        TR "%s -w 14 -a L;${location};%s -w 66;${ZFSA_INVENTORY[${location}.desc]}"; TR

        # Location내의 ZFSA Controller 리스트 
        zfsa_list=($(echo "${ZFSA_INVENTORY[${location}.zfsa]}" | tr "," " "))
        BD "-" ${tbl_row_width}
        for zfsa in ${zfsa_list[@]}; do
            # BD "-" ${tbl_row_width}
            pools=($(echo ${ZFSA_USAGE[${location}.${zfsa}.pools]} | tr "," " "))
            npool=${#pools[@]}
            projects=($(echo ${ZFSA_USAGE[${location}.${zfsa}.projects]} | tr "," " "))
            nproject=${#projects[@]}

            pool_total=0; pool_used=0; pool_avail=0;
            for pool_name in ${pools[@]}; do
                pool_total=$(( ${pool_total} +  ${ZFSA_USAGE[${location}.${zfsa}.${pool_name}.ptotal]} ))
                pool_used=$(( ${pool_used} +  ${ZFSA_USAGE[${location}.${zfsa}.${pool_name}.usage_total]} ))
                pool_avail=$(( ${pool_avail} +  ${ZFSA_USAGE[${location}.${zfsa}.${pool_name}.pavail]} ))
            done

            TR "%s -w 14;;%s -w 10 -a C;${zfsa};${npool};${nproject};%s -a R;$(number2str ${pool_total} 0);$(number2str ${pool_used} 0);%s -w 16;$(number2str ${pool_avail} 0) ($(( ${pool_avail} * 100 / ${pool_total} ))%) "; TR
        done
        BD "=" ${tbl_row_width}
    done
}

# Parameter:
#   $1: location (optional)
show_zfsa_usage_by_project() {
    # Location 정보가 없으면
    if [[ -z ${1} ]]; then 
        location=""
        zfsa_list=($(echo "${ZFSA_INVENTORY[zfsa]}" | tr "," " "))
    # Location 정보가 있으면
    else 
        location=${1}
        zfsa_list=($(echo "${ZFSA_INVENTORY[${location}.zfsa]}" | tr "," " "))
        # Location 정보가 있으면 ZFSA_USAGE의 키는 location.zfsa 
        for i in ${!zfsa_list[@]}; do 
            zfsa_list[${i}]="${location}.${zfsa_list[${i}]}"
        done
    fi

    # 전체 풀과 프로젝트 리스트
    all_pools=""; all_projects=""
    for zfsa in ${zfsa_list[@]}; do
        all_pools+="${ZFSA_USAGE[${zfsa}.pools]},"
        all_projects+="${ZFSA_USAGE[${zfsa}.projects]},"
    done 
    
    # pool 이름으로 홀/짝으로 좌우 정렬하고 어레이로 생성
    all_pools=($(relocate_str_by_name "${all_pools}" | tr "," " "))
    # 프로젝트 정렬, 중복 제거
    all_projects=($(echo ${all_projects} | tr "," "\n" | sort -u | tr "\n" " "))

    # 테이블 표시 형식 정의
    [[ ${#all_pools[@]} -gt 2 ]] && tr_width_usage_col=6 || tr_width_usage_col=8
    tr_width_pool_col=$(( tr_width_usage_col * 3 ))
    tbl_row_width=$(( ${tr_width_pool_col} + ${#all_pools[@]} * ${tr_width_pool_col} + ${tr_width_pool_col} ))

    # 상단 헤더    
    BD "=" ${tbl_row_width}
    TR "%s -a C -w ${tbl_row_width} -l | -c | -r | -fc GREEN"
    [[ ! -z ${location} ]] && TR "[${1}] ZFS Backup Appliance Usage;%s -fc NORMAL" || TR "ZFS Backup Appliance Usage;%s -fc NORMAL"; TR
    TR " "; TR; TR " "; TR

    ## Pool 사용 현황 요약 
    TR "%s -a L"
    for zfsa in ${zfsa_list[@]}; do
        zfsa_pools=($(echo ${ZFSA_USAGE[${zfsa}.pools]} | tr "," " "))
        TR "%s -fc LRED; [ ${zfsa} ];%s -fc NORMAL"; TR
        # Pool 사용 현황 요약
        for pool_name in ${zfsa_pools[@]}; do
            # ZFSA 풀 리스트에 풀이 존재하면
            if [[ $(in_str ${ZFSA_USAGE[${zfsa}.pools]} ${pool_name}) -eq 0 ]]; then 
                pool_total=${ZFSA_USAGE[${zfsa}.${pool_name}.ptotal]}
                pool_used=${ZFSA_USAGE[${zfsa}.${pool_name}.usage_data]}
                pool_avail=${ZFSA_USAGE[${zfsa}.${pool_name}.pavail]}
                TR "   ${pool_name} - Total: $(number2str ${pool_total}), Used: $(number2str ${pool_used}), Available: $(number2str ${pool_avail}) ($(( ${pool_avail} * 100 / ${pool_total} ))%)"; TR
            fi
        done 
    done 

    # 사용 현황 출력 문자열 생성
    pool_total_str="%s -a R;TOTAL ;%s -a C;"; pool_used_str="%s -a R;Used_Data ;%s -a C;"; pool_snap_str="%s -a R;Snapshot_Data ;%s -a C;"; pool_repl_str="%s -a R;Replication_Data ;%s -a C;"; pool_used_total_str="%s -a R;Used_Total ;%s -a C;"; pool_avail_str="%s -a R;Available ;%s -a C;"; pool_avail_ratio_str=";"
    pool_total_sum=0; pool_used_sum=0; pool_snap_sum=0; pool_repl_sum=0; pool_used_total_sum=0; pool_avail_sum=0;

    for pool_name in ${all_pools[@]}; do 
        for zfsa in ${zfsa_list[@]}; do
            zfsa_pools="${ZFSA_USAGE[${zfsa}.pools]}"

            # ZFSA 풀 리스트에 풀이 존재하면
            if [[ $(in_str ${zfsa_pools} ${pool_name}) -eq 0 ]]; then 
                pool_total=${ZFSA_USAGE[${zfsa}.${pool_name}.ptotal]}
                pool_used=${ZFSA_USAGE[${zfsa}.${pool_name}.usage_data]}
                pool_snap=${ZFSA_USAGE[${zfsa}.${pool_name}.usage_snapshots]}
                pool_repl=${ZFSA_USAGE[${zfsa}.${pool_name}.usage_replication]}
                pool_used_total=${ZFSA_USAGE[${zfsa}.${pool_name}.usage_total]}
                pool_avail=${ZFSA_USAGE[${zfsa}.${pool_name}.pavail]}

                pool_total_sum=$(( ${pool_total_sum} + ${pool_total} ))
                pool_used_sum=$(( ${pool_used_sum} + ${pool_used} ))
                pool_snap_sum=$(( ${pool_snap_sum} + ${pool_snap} ))
                pool_repl_sum=$(( ${pool_repl_sum} + ${pool_repl} ))
                pool_used_total_sum=$(( ${pool_used_total_sum} + ${pool_used_total} ))
                pool_avail_sum=$(( ${pool_avail_sum} + ${pool_avail} ))

                pool_total_str+="$(number2str ${pool_total});"
                pool_used_str+="$(number2str ${pool_used});"
                pool_snap_str+="$(number2str ${pool_snap});"
                pool_repl_str+="$(number2str ${pool_repl});"
                pool_used_total_str+="$(number2str ${pool_used_total});"
                pool_avail_str+="$(number2str ${pool_avail});"
                pool_avail_ratio_str+="[$(( ${pool_avail} * 100 / ${pool_total} ))%];"
            fi 
        done
    done 

    pool_total_str+="$(number2str ${pool_total_sum})"
    pool_used_str+="$(number2str ${pool_used_sum})"
    pool_snap_str+="$(number2str ${pool_snap_sum})"
    pool_repl_str+="$(number2str ${pool_repl_sum})"
    pool_used_total_str+="$(number2str ${pool_used_total_sum})"
    pool_avail_str+="$(number2str ${pool_avail_sum})"
    pool_avail_ratio_str+="[$(( ${pool_avail_sum} * 100 / ${pool_total_sum} ))%]"
    
    ## Pool 사용 현황 상세
    BD "=" ${tbl_row_width}
    # 타이틀 출력
    TR "%s -a C -w ${tr_width_pool_col} -l | -c | -r |"
    TR "POOL NAME;$(echo ${all_pools[@]} | tr " " ";");SUM TOTAL"; TR
    BD "-" ${tbl_row_width}

    TR "${pool_total_str}"; TR
    TR "${pool_used_str}"; TR
    TR "${pool_snap_str}"; TR
    TR "${pool_repl_str}"; TR
    TR "${pool_used_total_str}"; TR
    TR "${pool_avail_str}"; TR 
    TR "${pool_avail_ratio_str}"; TR
    BD "=" ${tbl_row_width}

    ## 프로젝트 상세 현황
    pool_str=""
    for pool_name in ${all_pools[@]}; do
        pool_str+="DATA;SNAP;TOTAL;"
    done 
    # 마지막 ; 문자 제거
    pool_str=$(echo "${pool_str}" | sed 's/.$//')

    # 타이틀 출력
    TR "%s -a C -w ${tr_width_pool_col} -l | -c | -r |"
    TR "PROJECTS;%s -w ${tr_width_usage_col};${pool_str};%s -w ${tr_width_pool_col};SUM TOTAL"; TR
    BD "-" ${tbl_row_width}
    
    project_used_str=""
    for project_name in ${all_projects[@]}; do
        project_used_sum=0
        project_used_str="%s -a R;${project_name} ;%s -a C;"

        for pool_name in ${all_pools[@]}; do 
            for zfsa in ${zfsa_list[@]}; do
                # ZFSA Controller의 풀, 프로젝트 리스트
                zfsa_pools="${ZFSA_USAGE[${zfsa}.pools]}"
                zfsa_projects="${ZFSA_USAGE[${zfsa}.${pool_name}.projects]}"

                # 콘트롤러에 풀이 존재하지 않으면
                if [[ $(in_str ${zfsa_pools} ${pool_name}) -ne 0 ]]; then 
                    continue 
                fi 

                # echo "ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_total=${used_total}"
                # 프로젝트가 존재하면 사용량 표시
                if [[ $(in_str ${zfsa_projects} ${project_name}) -eq 0 ]]; then 
                    used_data=${ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_data]}
                    used_snapshot=${ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_snapshot]}
                    used_total=${ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_total]}

                    # 프로젝트 사용량 합계
                    project_used_sum=$((${project_used_sum} + ${used_total}))

                    # 숫자를 문자열로 변환
                    used_data=$(number2str ${used_data} 0)
                    used_snapshot=$(number2str ${used_snapshot} 0)
                    used_total=$(number2str ${used_total} 0)

                    project_used_str+="%s -a C -w ${tr_width_usage_col};${used_data};${used_snapshot};${used_total};"
                # 프로젝트가 존재하지 않으면 X로 표시               
                else 
                    project_used_str+="%s -a C -w ${tr_width_usage_col};-;-;-;"
                fi 
            done 
        done

        project_used_sum=$(number2str ${project_used_sum})
        project_used_str+="%s -w ${tr_width_pool_col};${project_used_sum}"
        TR "%s -c |;${project_used_str}"; TR 
    done
    BD "=" ${tbl_row_width}
}

# 인베토리 파일을 사용하지 않을때, ZFSA 로긴 스트링으로 인벤토리 정보 생성
# Location 정보 사용 하지 않음
parsing_inventory_env() {
    # ZFSA 로긴 스트링으로 접속 컨트롤러 수 확인
    noctl=$(set | grep ^${ZFSA_LOGINSTR_PREFIX} | wc -l)
    
    for i in $(seq 1 ${noctl}); do 
        # ZFSA 이름은 로긴 스트링의 서버명으로
        zfsa_login_str=$(eval "echo $"{${ZFSA_LOGINSTR_PREFIX}${i}}"")
        zfsa_name=$(echo ${zfsa_login_str} | cut -d"@" -f 2)
        # 접속 스트링은 uid:ZFSA Controller
        zfsa_connection_str=$(echo ${zfsa_login_str} | tr "@" ":")
        
        # ZFSA 로긴 스트링 환경 변수로 구성시 로케이션 설정 안함
        ZFSA_INVENTORY[LOC]=""
        ZFSA_INVENTORY[zfsa]+="${zfsa_name},"
        ZFSA_INVENTORY[${zfsa_name}]=${zfsa_connection_str}
    done 
}

# config 파일에서 ZFSA와 DB서버 정보 확인
# 구성 파일의 내용을 ZFSA 구성 정보로 설정
# ini 파일의 []내용은 ZFSA 업무/센터 등의 구분자로(LOC:Location)
# ;;는 Location의 부가 설명 
parsing_inventory_file() {
    while read -r line; do
        if [[ ${line:0:1} == \# || -z ${line} ]]; then  
            continue;
        fi

        # 섹션-Location
        if [[ ${line:0:1} == "[" && ${line:${#line}-1:1} == "]" ]]; then
            loc=$(echo ${line} | sed 's/^\[//;s/\]$//')
            ZFSA_INVENTORY[LOC]+="${loc},"
        # 디스크립션
        elif [[ ${line:0:2} == ";;" ]]; then 
            ZFSA_INVENTORY[${loc}.desc]="${line:2:${#line}-1}"
        else 
            # ZFSA 이름과 접속 정보를 분리
            zfsa_name=$(echo "${line}" | awk '{print $1}')
            zfsa_connection_str=$(echo "${line}" | awk '{print $3":"$2":"$4}')
            
            ZFSA_INVENTORY[${loc}.zfsa]+="${zfsa_name},"
            ZFSA_INVENTORY[${loc}.${zfsa_name}]=${zfsa_connection_str}
        fi
    done < ${INVENTORY_FILE}
}

# 
# Parameter:
#   $1: ZFSA Controller 리스트 문자열
#   $2: Location (optional)
get_usage() {
    # 문자열을 어레이로 변환
    zfsa_list=($(echo "${1}" | tr "," " "))

    for zfsa in ${zfsa_list[@]}; do
        # Location이 없으면
        if [[ -z ${2} ]]; then
            login_str="$(echo ${ZFSA_INVENTORY[${zfsa}]} | tr ":" " ") ${zfsa}"
        else 
            login_str="$(echo ${ZFSA_INVENTORY[${2}.${zfsa}]} | tr ":" " ") ${zfsa} ${2}"
        fi 
        
        # ZFSA 구성 정보를 파일로 저장
        if [[ ! -z ${DUMP_FILE} ]]; then 
            get_zfsa_usage ${login_str} >> ${DUMP_FILE}
        # ZFSA 구성 정보 로딩
        else 
            eval "$(get_zfsa_usage ${login_str})"
        fi 
    done
}

# 인벤토리 파일 또는 ZBRM 프로파일로 인벤토리 정보 생성
# 인베토리 정보를 이용해 ZFSA Controller에 접속해 현황 정보 로딩
init() {

    # Common function 로딩
    . ./common.sh

    # 인벤토리 파일이 없으면, ZBRM 프로파일 정보 사용 
    if [[ -z ${INVENTORY_FILE} || ! -f ${INVENTORY_FILE} ]]; then
        parsing_inventory_env
    # 인벤토리 파일을 지정하면
    else 
        parsing_inventory_file 
    fi  

    # 덤프 파일의 구성 정보 로딩
    if [[ -f ${DEBUG_FILE} ]]; then 
        eval "$(cat ${DEBUG_FILE})"
    # ZFSA에 접속해 구성 정보 로딩
    else 
        # Location 정보가 없으면
        if [[ -z ${ZFSA_INVENTORY[LOC]} ]]; then 
            get_usage ${ZFSA_INVENTORY[zfsa]}
        else 
            loc_list=($(echo "${ZFSA_INVENTORY[LOC]}" | tr "," " "))
            
            for loc in ${loc_list[@]}; do
                get_usage ${ZFSA_INVENTORY[${loc}.zfsa]} ${loc}
            done
        fi
    fi 
}

help() {
cat <<USAGEINFO
usage: showdashboard.sh [-ido]
    [-i | --inventory] inventory_file   
        인벤토리 파일 설정, 설정하지 않으면 INVENTORY_FILE 환경 변수에 정의된 파일명 사용
        인벤토리 파일이 없으면, ZBRM Profile의 LOGINSTRING_# 환경 변수의 ZFSA 설정 값 사용
    [-d | --debug] dump_file
       덤프 파일을 이용해한 테스트
    [-o | --out] dump_file
        덤프 파일 생성
USAGEINFO
    exit 1
}

# Arguments 파싱
parsing_arg() {
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -i|--inventory)
                shift 1
                if [[ -z ${1} ]]; then
                    help
                else
                    INVENTORY_FILE="${1}"
                    shift 1
                fi
                ;;
            -d|--debug)
                shift 1
                # ZFSA 덤프 파일 로딩
                if [[ ! -z ${1} ]]; then 
                    DEBUG_FILE="${1}"
                    shift 1
                fi    
                ;;
            -o|--out)
                shift 1
                # ZFSA 덤프 파일로 생성
                if [[ ! -z ${1} ]]; then 
                    DUMP_FILE="${1}"
                    shift 1
                fi     
                ;; 
            *)
                shift 1
                ;;
        esac
    done
}

# Main rountie
# 수행 옵션 파싱
parsing_arg "${@}"

# 인벤토리 정보 구성, ZFSA 구성 정보 로딩
init 

# 덤프 파일 생성이면 종료
if [[ ! -z ${DUMP_FILE} ]]; then 
    exit 0
fi 

# Location 설정이 없으면, 현황 정보 출력 후 종료
if [[ -z ${ZFSA_INVENTORY[LOC]} ]]; then
    clear
    show_zfsa_usage_by_project
else
    # Location 설정이 있으면 화면 네비게이션 모드로
    selection=HOME
    curr_loc=""
    prompt_msg=""

    while [[ ! ${selection} == quit ]]; do
        clear

        if [[ $(in_str ${ZFSA_INVENTORY[LOC]} ${selection}) -eq 0 ]]; then
            curr_loc=${selection}
            show_zfsa_usage_by_project ${selection}
            prompt_msg="Select Location or quit: "
        elif [[ ! -z ${curr_loc} && $(in_str ${ZFSA_INVENTORY[${curr_loc}.zfsa]} ${selection}) -eq 0 ]]; then
            show_zfsa_detail ${curr_loc} ${selection}
            prompt_msg="Select Location or quit: "
        else
            curr_loc=""
            show_zfsa_list_by_loc
            prompt_msg="Select location or quit: "
        fi  

        read -p "${prompt_msg}" selection
        # selection=$(echo ${selection} | tr '[:lower:]' '[:upper:]')

        # 아무 입력이 없으면
        [[ -z ${selection} ]] && selection=HOME
    done 
fi

#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
# End of script
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
