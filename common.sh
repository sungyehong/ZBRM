
# Text Color
RED="\033[0;31m"
LRED="\033[1;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
LGRAY="\033[0;37m"
DGRAY="\033[0;30m"
NORMAL="\033[0m"

# 용량 출력시 소수점 이하 자리 수(0=>소수점이하 절삭, 2=>1자리...)
DECIMALPOINT=1

TB=1000000000000
GB=1000000000
MB=1000000
KB=1000

# 용량 값을 문자열로 변환
# 소수점이하 자리수는 decimal로 조정(0=>소수점이하 절삭, 2=>1자리...) 
# Parameter:
#   $1: number
#   $2: decimal point (default: 1)
number2str() {
   # number와 decimal이 없으면
   number=${1:-0}
   decimal=${2:-1}
   
   if [[ ${number} -ge ${TB} ]]; then 
      tostr=$(echo "scale=${decimal}; ${number}/${TB}" | bc)
      unit_str="TB"    
   elif [[ ${number} -ge ${GB} ]]; then
      tostr=$(echo "scale=${decimal}; ${number}/${GB}" | bc)
      unit_str="GB"
   elif [[ ${number} -ge ${MB} ]]; then
      tostr=$(echo "scale=${decimal}; ${number}/${MB}" | bc)
      unit_str="MB"
   elif [[ ${number} -ge ${KB} ]]; then
      tostr=$(echo "scale=${decimal}; ${number}/${KB}" | bc)
      unit_str="KB"
   else 
      tostr=${number}
      unit_str=""
   fi 

   # 0이면 -으로 표시
   [[ ${tostr} == "0" ]] && tostr="-"

   # 소수점 이하가 .0이면 소수점 이하 삭제 1.0 => 1
   # tostr=$(echo ${tostr} | sed 's/.0$//')"${unit_str}"
   tostr="${tostr}${unit_str}"

    echo ${tostr}
}

# 문자열에 단어 확인
#   Parameter:
#   $1: 문자열
#   $2: 찾을 단어
in_str() {
   echo "${1}" | grep -qw ${2}

   echo $?
}

# 어레이 항목 확인
#   Parameter:
#   $1: 어레이
#   $2: 찾을 값
in_array() {
   for i in ${!1[@]}; do
      if [[ ${i} == "${2}" ]]; then
         echo 0
      fi
   done
   
   echo 1
}

# 컬럼 출력 형식 설정
# 한번 설정한 형식 지정은 형식 지정을 새로 하지 않으면 유지
# Parameter:
#  $@: 형식 지정 
SETTD() {
   while [[ ${#} -gt 0 ]]; do
      case ${1} in
         -a|--align)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then 
               TDALIGN=${1}
            fi
            shift 1
            ;;
         -w|--width)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then
               TDWIDTH=${1}
            fi 
            shift 1
            ;;
         -p|--pad)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then
               TDPAD=${1}
            fi
            ;;
         -fc|--font_color)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then
               eval TDCOLOR=$(echo "$"${1})
            fi
            ;;
         *)
            shift 1
            ;;
      esac
   done
}

# 테이블 컬럼 출력
# Parameter:
#  $1: 컬럼 문자열
#  $@: 형식 지정 (-a: 정렬, -w: 컬럼 넓이)
TD() {
   # 파라미터가 없으면 줄바꿈
   if [[ ${#} -eq 0 ]]; then
      printf "\n"
      return 0
   fi 

   TDSTR="${1}"
   shift 1; SETTD "${@}"

   # 컬럼 문자열 정렬을 지정하지 않으면 가운데 정렬 
   [[ -z ${TDALIGN} ]] && TDALIGN="C"

   # 컬럼 넓이를 지정하지 않으면 문자열 크기
   [[ -z ${TDWIDTH} ]] && TDWIDTH=${#TDSTR}

   # 문자열이 지정 크기로 조정
   TDSTR=${TDSTR::${TDWIDTH}}

   [[ ${TDPAD} -gt 0 ]] && printf "%-${TDPAD}s" " "

   case ${TDALIGN} in
      L)
         fmt="%-${TDWIDTH}s"
         ;;
      R)
         fmt="%${TDWIDTH}s"
         ;;
      *)
         # 가운데 정렬이고 지정 크기보다 문자 길이가 작으면
         if [[ ${TDWIDTH} -gt $((${#TDSTR} + 1)) ]]; then 
            # 좌우 마진 
            m=$(((${TDWIDTH}-${#TDSTR})/2))
            TDSTR=$(printf "%${m}s%${#TDSTR}s%${m}s" " " "${TDSTR}" " ")
         fi
         fmt="%${TDWIDTH}s"
         ;;
   esac 

   [[ ! -z ${TDCOLOR} ]] && printf ${TDCOLOR}
   printf ${fmt} "${TDSTR}" 
   [[ ! -z ${TDCOLOR} ]] && printf ${NORMAL}
}

# 컬럼 출력 형식 설정
# Parameter:
#   $@: 형식 지정 
SETTR() {
   while [[ ${#} -gt 0 ]]; do
      case ${1} in
         -w|--width)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then 
               TRWIDTH=$(( ${1} - 1 ))
               shift 1
            fi 
            ;;
         -a|--align)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then 
               TRALIGN=${1}
               shift 1
            fi
            ;;
         -l|--lbar)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then 
               TRLBAR=${1}
               shift 1
            else 
               TRLBAR=" "
            fi 
            ;;
         -c|--cbar)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then 
               TRCBAR=${1}
               shift 1
            else 
               TRCBAR=" "
            fi 
            ;;
         -r|--rbar)
            shift 1
            if [[ ! -z ${1} &&  ${1} != -* ]]; then 
               TRRBAR=${1}
               shift 1
            else 
               TRRBAR=" "
            fi 
            ;;
         -p|--padding)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then 
               TRPAD=${1}
               shift 1
            fi
            ;;
         -fc|--font_color)
            shift 1
            if [[ ! -z ${1} && ${1} != -* ]]; then
               TRCOLOR=${1}
            fi
            ;;
         *)
            shift 1
            ;;
      esac
   done 
}

# 테이블 행 출력 형식 설정
# Parameter:
#  $1: 행 문자열 (; 구분, ;의 앞뒤 여백도 컬럼에 포함됨)
#  $@: 출력 옵션  
# 사용 예:
#  TR "%s -w 20  "
#  TR "%s -l |"
#  TR "HELLO;12345";TR
#  TR "%s -w 20 -l | -a C;HELLO;12345;%s -w10;HELLO;12345"; TR
TR() {
   # 파라미터 없이 호출하면 줄바꿈 
   if [[ -z ${1} ]]; then 
      TD; return 0
   fi 
   
   # 테이블내 컬럼 문자열에 스페이스가 포함되어 있을 수 있어 ; 문자로 구분
   oldifs=$IFS; IFS=";"
   # 컬럼 문자열을 어레이형으로
   TRSTR=($(echo "${1}"))
   IFS=${oldifs}

   # 패딩 설정이 있으면, 패딩 사용은 사전 선언 필요
   # TR "%s -p 5"; TR "Hello"
   [[ ${TRPAD} -gt 0 ]] && TD " " -w ${TRPAD}

   # 출력 컬럼 수 사전 확인
   # 출력 물자열에 형식 설정과 문자열이 같이 있어 실제 출력될 컬럼수 확인 
   colno=0
   for i in ${!TRSTR[@]}; do
      [[ ! ${TRSTR[${i}]:0:2} == "%s" ]] && colno=$((${colno} + 1))
   done

   # 컬럼 출력
   colpos=0
   
   for i in ${!TRSTR[@]}; do
      # 출력 형식 설정
      if [[ ${TRSTR[${i}]:0:2} == "%s" ]]; then 
         SETTR ${TRSTR[${i}]:2:${#TRSTR[${i}]}}
      else 
         colpos=$((${colpos} + 1))

         # width가 선언되지 않으면 컬럼 문자열 길이
         [[ -z ${TRWIDTH} ]] && TRWIDTH=${#TRSTR[${i}]}
         [[ -z ${TRALIGN} ]] && TRALIGN=C
         
         # 첫번째 컬럼 시작
         if [[ ${colpos} -eq 1 ]]; then 
            [[ ! -z ${TRLBAR} ]] && TD "${TRLBAR}" -w 1 -fc ${TRCOLOR} || TD " " -w 1
         fi

         # 마지막 컬럼이면
         if [[ ${colpos} -eq ${colno} ]]; then 
            TD "${TRSTR[${i}]}" -w $(( ${TRWIDTH} - 1 )) -a ${TRALIGN} -fc ${TRCOLOR}
            [[ ! -z ${TRRBAR} ]] &&  TD "${TRRBAR}" -w 1 -fc ${TRCOLOR} || TD " " -w 1
         else 
            TD "${TRSTR[${i}]}" -w ${TRWIDTH} -a ${TRALIGN} -fc ${TRCOLOR}
            [[ ! -z ${TRCBAR} ]] && TD "${TRCBAR}" -w 1 -fc ${TRCOLOR} || TD " " -w 1
         fi 
      fi
   done
}

# 가로선 출력
# Parameter:
#  $1: 구분선 문자
#  $2: 구분선 길이
#  $3: 패딩 (optional)
BD() {
   # 좌측 패딩 
   if [[ ${3} -gt 0 ]]; then
      for i in $(seq 1 ${3}); do
         TD " "
      done
   fi

   TD "+" 
   for i in $(seq 1 $((${2} - 2))); do
      TD ${1}
   done
   TD "+"; TD
}

# 문자열 리스트를  홀수는 좌측 짝수는 우축으로 정렬
# Parameter:
#  $1: 문자열 ,로 구분 
relocate_str_by_name() {
    odd_list=""
    even_list=""

    # 소팅하고, 어레이 형으로 변환
    list=($(echo ${1} | tr "," " " | sort | tr "\n" " "))

    for name in ${list[@]}; do
        # 마지막 문자만 추출
        last_number=$(echo ${name} | awk '{print substr($0, length,1)}')
        last_number=$((${last_number} % 2))
        
        if [[ ${last_number} -eq 0 ]]; then 
            even_list+="${name},"
        else 
            odd_list+="${name},"
        fi 
    done 

    # 풀 리스트 합치고 마지막 , 문자 제거후 반환
    echo $(echo "${odd_list}${even_list}" | sed 's/.$//')
}

# SSL 연결 확인
# Parameter:
#   $1: IP Address
#   $2: User ID
validate_connection() {
    if [[ -z ${1} || -z ${2} ]]; then 
        echo "usage: ${0} <ip address> <user id>"
        return 1
    else  
        # 연결 시도
        ssh -q -o ConnectTimeout=${SSH_TIMEOUT} ${2}@${1} exit
        rtn_code=${?}
        
        if [[ ${rtn_code} -ne 0 ]]; then 
            echo "${LRED}Connect to host ${1} timed out${NORMAL}"
        fi

        return ${rtn_code} 
    fi
}

# 리무트 서버에 SQL 실행
# Parameter:
#   $1: IP Address
#   $2: User ID
#   $3: SQL Statement
#   $4: sqlplus login string (optional, Default: / as sysdba)
runsql() {
    # loging string를 지정하지 않으면
    login_str=${4:-/ as sysdba}

    ret_var=$(ssh -o ConnectTimeout=${SSH_TIMEOUT} ${2}@${1} sqlplus -s ${login_str} <<EOF
WHENEVER OSERROR EXIT 5;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
${3}
EXIT;
EOF
)
    rtn_code=${?}
	if [[ ${rtn_code} -eq 5 ]] ; then
		SQLRUNERROR="sqlplus 실행중 OS 에러 발생 했습니다. ${ret_var}"
		unset ret_var
	elif [[ $rtn_code -ne 0 ]] ; then
		SQLRUNERROR="sqlplus 실행중 SQL 에러 발생 했습니다. ${ret_var}"
		unset ret_var
	fi
    
    echo "${ret_var}"
}
