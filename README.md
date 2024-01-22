## ZFSA 사용 현황을 보여주는 스크립트

1. Inventory 파일 생성
   - zbrmusage.sh 스크립트 12행에 인벤토리 파일 위치 정의 (Defaul: ./inventory.ini)
   - inventory 파일 내에 [ZFSA] 섹션에 ZFSA Appliance 접속 정보 리스트 생성
   - inventory 파일 내에 [ORADB] 섹션에 Oracle DB Server 접속 정보 리스트 생성 (현재 미사용)
  
2. zbrmusage.sh 스크립트 실행
   - 스크립트는 ZFSA 사용 현황을 딕셔너리(Dictionary, Associate Array) 데이터 구조를 사용함
   - bash와 ksh에 따른 환경 설정 zbrmusage.sh 스크립트 20행~30행
   - 현 실행 환경은 테스트 목적으로 ZFSA 현황 내용을 파일로(zfsa.out) 생성하고, 2개의 콘트롤러 4개의 다른 이름의(1,2,3,4) 풀을 생성해 테스트
   - ZFSA에 접속해 테스트 할려면, zbrmusage.sh 스크립트 540행을 언코멘트, 543행을 코멘트 처리
