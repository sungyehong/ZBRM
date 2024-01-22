#!/bin/sh
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
# 
# ZFS Appliance Usage v0.72
# 
# zbrmusage.sh [-if]
# - zfsadashboard.sh -i 5 -f inventory.ini       ZFSA Resource 상태 5초 간격으로 보기
#			
# Bug fix:
#   - Controller에 풀, 프로젝트가 없을 때의 오류
#   - ksh ~= 미지원 : string = *substring* 으로 변경
# Enhancement:
#   - 멀티 센터에 대한 지원(동일 풀이름 구성 지원) => TBD
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# Default inventory 파일
INVENTORY_FILE=./inventory.ini

# 업데이트 대기 시간 (0: 1회 수행, n: n초 간격으로 반복)
INTERVAL=0
# 업데이트 시간 최소값 
MIN_INTERVAL=5

# Dictionary 데이터 구조 생성
if [[ $SHELL == "/bin/ksh" ]]; then 
    typeset -A ZFSA_INVENTORY
    typeset -A ORADB_INVENTORY
    typeset -A ZFSA_USAGE
    typeset -A ORADB_USAGE
else 
    declare -A ZFSA_INVENTORY
    declare -A ORADB_INVENTORY
    declare -A ZFSA_USAGE
    declare -A ORADB_USAGE
fi

# ZFS Appliance 현황 정보를 딕셔너리 구조의 문자열로 리턴
# Parameter:
#   $1: IP address
#   $2: User ID
#   $3: ZFSA Name 
get_zfsa_usage() {

    zfsa_script="
    script
    {
        const ZFSA_CTL='${3}';
        // 용량 단위 환산을 위한 상수
        const TB = 1000000000000;
        const GB = 1000000000;
        const MB = 1000000;
        const KB = 1000;
        // 용량 출력시 소수점 이하 자리 수(0=>소수점이하 절삭, 2=>1자리...)
        const DECIMAL_POINT = 2; 

        // 사용 현황 객체 변수
        // var ZFSA_USAGE = {};

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

        // Hardware info
        function get_hardware() {
            run('cd /');
            run('maintenance');
            run('hardware');

            hwlist = list();
            for(hw=0; hw<hwlist.length; hw++) {
                print(hwlist[hw]);
            }
            
            // list -> select chassis matched name -> select disk
            // zfsa_system_state= state = ok, or ??
            // ZFSA_USAGE[]
            // zfsa_disk_state= no of disks, ok or ??
            // hardware_disks = ''; 
        }

        // ZFSA Controller 전체 풀 리스트 딕셔너리 문자열로 출력
        // 전체 풀: ZFSA_USAGE=[ZFSACTL.pools]
        function get_pool() {
            run('cd /');
            run('status');
            run('storage');

            zfsa_pools = list();

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.pools]=\"';
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

                ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.'+pool_name+'.projects]=\"';
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

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.projects]=\"';
            ret_str = ret_str + zfsa_projects.toString();
            ret_str = ret_str + '\"';

            // 전체 프로젝트 리스트를 출력
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');
        }

        // ZFSA CPU, IO. NFS, NIC activity report
        function get_activity() {
            run('cd /');
            run('status');
            run('activity');

            // Activity 객체 생성
            zfsa_activity = {};

            // CPU Utilization(%)
            run('select cpu.utilization');
            zfsa_activity.cpu = parseInt(run('get average').split(/\s+/)[3]);
            run('cd ..');

            // I/O operation(op/sec)
            run('select io.ops');
            zfsa_activity.io = parseInt(run('get average').split(/\s+/)[3]);
            run('cd ..');

            // NFS operation(op/sec)
            run('select nfs3.ops');
            zfsa_activity.nfs = parseInt(run('get average').split(/\s+/)[3]);
            run('cd ..');

            run('select nfs4.ops');
            zfsa_activity.nfs += parseInt(run('get average').split(/\s+/)[3]);
            run('cd ..');
            
            // Network bandwidth
            run('select nic.kilobytes')
            zfsa_activity.nic = parseInt(run('get average').split(/\s+/)[3]);

            // Resource activity를 dictionary 구조의 문자열로 출력
            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.activity.cpu]='+zfsa_activity.cpu;
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.activity.io]='+zfsa_activity.io;
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.activity.nfs]='+zfsa_activity.nfs;
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.activity.nic]='+zfsa_activity.nic;
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');
        }

        // ZFSA 스토리지 풀 사용 현황 
        // used, avail, total 용량을 바이트 단위로 출력
        function get_usage_by_pool(pool_name) {
            run('cd /');
            run('status');
            run('storage');
            run('select ' + pool_name);

            used = change2byte(run('get used').split(/\s+/)[3]);
            avail = change2byte(run('get avail').split(/\s+/)[3]);
            total = used + avail;

            // Pool usage를 dictionary 구조의 문자열로 출력
            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.'+pool_name+'.used]='+parseFloat(used).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.'+pool_name+'.avail]='+parseFloat(avail).toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.'+pool_name+'.total]='+parseFloat(total).toString();
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
            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.'+pool_name+'.'+project_name+'.used_data]='+used_data.toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.'+pool_name+'.'+project_name+'.used_snapshot]='+used_snapshot.toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');

            ret_str = 'ZFSA_USAGE['+ZFSA_CTL+'.'+pool_name+'.'+project_name+'.'+'used_total]='+used_total.toString();
            fmt = '%-'+ret_str.length+'s';
            printf(fmt, ret_str); print('');
        } 

        // Main 
        try {
            // get_hardware();
            get_pool();
            get_project();
            get_activity();

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
    
    ret_val=$(echo "$zfsa_script" | ssh -T -o ConnectTimeout=${SSH_TIMEOUT} "${2}@${1}" | grep -v Last)

    echo "$ret_val"
}

#  __  _   _          _                                               
#   / |_) |_) |\/|   |_)  _   _  _      ._ _  _    | |  _  _.  _   _  
#  /_ |_) | \ |  |   | \ (/_ _> (_) |_| | (_ (/_   |_| _> (_| (_| (/_ 
#                                                              _|     
show_zfsa_usage_by_project() {
    # 전체 풀과 프로젝트 리스트
    for zfsa in ${!ZFSA_INVENTORY[@]}; do
        all_pools+="${ZFSA_USAGE[${zfsa}.pools]},"
        all_projects+="${ZFSA_USAGE[${zfsa}.projects]},"
    done 
    
    # pool 이름으로 홀/짝으로 좌우 정렬하고 어레이로 생성
    all_pools=($(relocate_str_by_name "${all_pools}" | tr "," " "))
    # 프로젝트 정렬, 중복 제거
    all_projects=($(echo ${all_projects} | tr "," "\n" | sort -u | tr "\n" " "))

    # 테이블 표시 형식 정의
    tr_width_usage_col=6
    tr_width_pool_col=$(( tr_width_usage_col * 3 ))
    tbl_row_width=$(( ${tr_width_pool_col} + ${#all_pools[@]} * ${tr_width_pool_col} + ${tr_width_pool_col} ))
        
    BD "=" ${tbl_row_width}
    TR "%s -a L -w ${tbl_row_width} -l | -c | -r |"

    for zfsa in ${!ZFSA_INVENTORY[@]}; do
        TR " ${zfsa}"; TR
        TR "    Pool: ${ZFSA_USAGE[${zfsa}.pools]}"; TR
        TR "    CPU: ${ZFSA_USAGE[${zfsa}.activity.cpu]}%   I/O: ${ZFSA_USAGE[${zfsa}.activity.io]} IOPS    NFS: ${ZFSA_USAGE[${zfsa}.activity.nfs]} OPS    NET: ${ZFSA_USAGE[${zfsa}.activity.nic]} KB"; TR
    done    
    BD "=" ${tbl_row_width}

    # 
    BD "=" ${tbl_row_width}
    for pool_name in ${all_pools[@]}; do
        pool_str+="${pool_name};"
        pool_str1+=" ;"
        pool_str2+="DATA;SNAP;TOTAL;"
    done 
    # 마지막 ; 문자 제거
    pool_str=$(echo "${pool_str}" | sed 's/.$//')
    pool_str1=$(echo "${pool_str1}" | sed 's/.$//')
    pool_str2=$(echo "${pool_str2}" | sed 's/.$//')

    # 타이틀 행
    TR "%s -a C -w ${tr_width_pool_col} -l | -c | -r |"
    TR " ;${pool_str}; "; TR 
    TR " ;${pool_str1}; "; TR 
    TR "PROJECTS;%s -w ${tr_width_usage_col};${pool_str2};%s -w ${tr_width_pool_col};SUM"; TR
    BD "-" ${tbl_row_width}
    
    for project_name in ${all_projects[@]}; do
        project_used_sum=0
        project_used_str="${project_name};"

        for pool_name in ${all_pools[@]}; do 
            for zfsa in ${!ZFSA_INVENTORY[@]}; do
                # ZFSA Controller의 풀, 프로젝트 리스트
                zfsa_pools="${ZFSA_USAGE[${zfsa}.pools]}"
                zfsa_projects="${ZFSA_USAGE[${zfsa}.${pool_name}.projects]}"

                # 콘트롤러에 풀이 존재하지 않으면 
                if [[ ! ${zfsa_pools} = *${pool_name}* ]]; then 
                    continue 
                fi 

                # echo "ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_total=${used_total}"
                # 프로젝트가 존재하면 사용량 표시
                if [[ ${zfsa_projects} = *${project_name}* ]]; then 
                    used_data=${ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_data]}
                    used_snapshot=${ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_snapshot]}
                    used_total=${ZFSA_USAGE[${zfsa}.${pool_name}.${project_name}.used_total]}

                    # 프로젝트 사용량 합계
                    project_used_sum=$((${project_used_sum} + ${used_total}))

                    # 숫자를 문자열로 변환
                    used_data=$(number2str ${used_data})
                    used_snapshot=$(number2str ${used_snapshot})
                    used_total=$(number2str ${used_total})

                    project_used_str+="%s -w ${tr_width_usage_col};${used_data};${used_snapshot};${used_total};"
                # 프로젝트가 존재하지 않으면 X로 표시               
                else 
                    project_used_str+="%s -w ${tr_width_usage_col};X;X;X;"
                fi 
            done 
        done

        project_used_sum=$(number2str ${project_used_sum})
        project_used_str+="%s -w ${tr_width_pool_col};${project_used_sum}"
        TR "${project_used_str}"; TR 
    done
    BD "=" ${tbl_row_width}

    # Pool별 사용 현황
    pool_total_str="Total;"; pool_used_str="Used;"; pool_avail_str="Avail;"; pool_avail_ratio_str=";"
    pool_total_sum=0; pool_used_sum=0; pool_avail_sum=0

    for pool_name in ${all_pools[@]}; do 
        for zfsa in ${!ZFSA_INVENTORY[@]}; do
            zfsa_pools="${ZFSA_USAGE[${zfsa}.pools]}"
            if [[ ${zfsa_pools} =~ ${pool_name} ]]; then 
                pool_total=${ZFSA_USAGE[${zfsa}.${pool_name}.total]}
                pool_used=${ZFSA_USAGE[${zfsa}.${pool_name}.used]}
                pool_avail=${ZFSA_USAGE[${zfsa}.${pool_name}.avail]}

                pool_total_sum=$(( ${pool_total_sum} + ${pool_total} ))
                pool_used_sum=$(( ${pool_used_sum} + ${pool_used} ))
                pool_avail_sum=$(( ${pool_avail_sum} + ${pool_avail} ))

                pool_total_str+="$(number2str ${pool_total});"
                pool_used_str+="$(number2str ${pool_used});"
                pool_avail_str+="$(number2str ${pool_avail});"
                pool_avail_ratio_str+="[$(( ${pool_avail} * 100 / ${pool_total} ))%];"
            fi 
        done
    done 

    pool_total_str+="$(number2str ${pool_total_sum})"
    pool_used_str+="$(number2str ${pool_used_sum})"
    pool_avail_str+="$(number2str ${pool_avail_sum})"
    pool_avail_ratio_str+="[$(( ${pool_avail_sum} * 100 / ${pool_total_sum} ))%]"

    TR ${pool_total_str}; TR
    TR ${pool_used_str}; TR
    TR ${pool_avail_str}; TR
    TR ${pool_avail_ratio_str}; TR
    BD "=" ${tbl_row_width}
}

# config 파일에서 ZFSA와 DB서버 정보 확인
parsing_config_file() {

    while IFS=" " read -r name serverip userid option
    do
        # 코멘트, 빈줄 제거 
        if [[ ${name} =~ ^# || ${name} =~ ^\; || -z ${name} ]]; then                                 # Ignore comments / empty lines
            continue;
        fi
        
        # ZFSA 섹션이면
        if [[ ${name} =~ ^"["ZFSA"]"$ ]]; then
            section=ZFSA
        # ORADB 섹션이면
        elif [[ ${name} =~ ^"["ORADB"]"$ ]]; then
            section=ORADB 
        else 
            eval "${section}_INVENTORY[${name}]=${serverip}:${userid}:${option}"
        fi 
    done < ${INVENTORY_FILE}
}

# Arguments 파싱
parsing_arg() {
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -i|--interval)
                shift 1
                if [[ -z ${1} || ! ${1} =~ ^[0-9]+$ ]]; then
                    help
                else
                    INTERVAL=${1}
                    UPDATE_MODE="ON"
                fi

                shift 1
                ;;
            -f|--file)
                shift 1
                if [[ -z ${1} ]]; then
                    help
                else
                    INVENTORY_FILE="${1}"
                    shift 1
                fi
                ;;
        esac
    done
}

# inventory 파일 해석, 데이터 초기화
init() {

    # Common function 로딩
    . ./common.sh

    # 수행 옵션 파싱
    parsing_arg 

    # 인벤토리 파일이 없으면 
    if [[ -z ${INVENTORY_FILE} || ! -f ${INVENTORY_FILE} ]]; then
        echo -e ${RED}"Inventory file not found."${NORMAL}
        exit 1
    fi 

    # Inventory 파일 파싱후 ZFSA_INVENTORY, ORADB_INVENTORY dictionary 생성
    parsing_config_file ${INVENTORY_FILE}

    # 인벤토리 항목이 없으면
    if [[ ${#ZFSA_INVENTORY[@]} -eq 0 && ${#ORADB_INVENTORY[@]} ]]; then 
        echo -e ${RED}"Inventory file contains no items."${NORMAL}
        exit 1
    fi 
    
    # 모든 ZFSA Controller에 접속해 현황 정보를 딕셔너리 구조로 저장 
    for key in "${!ZFSA_INVENTORY[@]}"; do
        para=$(echo ${ZFSA_INVENTORY[$key]} | tr ":" " ") 
        
        # [테스트]현황 정보를 파일로 저장할때
        # get_zfsa_usage ${para} ${key} >> zfsa.out

        # [실사용]현황 정보의 딕셔너리 구조를 쉘 환경 변수로 
        # eval "$(get_zfsa_usage ${para} ${key})"
    done
    # [테스트] 저장된 파일의 딕셔너릴 구조를 쉘 환경 변수로 
    eval "$(cat ZFS9.out)"
}

# Main rountie
# 초기화
init 

while true :
do
    clear
    show_zfsa_usage_by_project

    if [[ ${INTERVAL} -eq 0 ]]; then
        break
    fi

    sleep ${INTERVAL}
done 

exit 0

#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
# End of script
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
