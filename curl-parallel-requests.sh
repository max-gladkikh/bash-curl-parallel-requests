#!/bin/bash

url='http://localhost:80/api?id='; # Замените на нужный URL
totalRequests=10 #Замените на нужное количество параллельных запросов

countSuccessRequests=0;
totalTimeAllSuccessRequests=0;
maxTotalTimeAllSuccessRequests=0;
minTotalTimeAllSuccessRequests=0;
connectTimeAllSuccessRequest=0;
pretransferTimeAllSuccessRequest=0;
starttransferTimeAllSuccessRequest=0;
namelookupTimeAllSuccessRequest='0';

start_time=$EPOCHREALTIME
dir_logs_and_responces="${start_time}_logs_and_responces"
mkdir "$dir_logs_and_responces"

urls=""
for (( i=1; i<=totalRequests; i++ )); do
  if (( i > 1 )); then
      urls+="--next\n"
  fi
  urls+="url = \"$url$i\"\n"
  urls+="verbose\n"
  urls+="data = \"id=$i\"\n"
  urls+="header = \"HeaderId: $i\"\n"
  urls+="output = \"$dir_logs_and_responces/response_$i.log\"\n"
  urls+="stderr = \"$dir_logs_and_responces/verboses.log\"\n" # тут к сожалению нет смысла разделять на файлы, т к всёравно всё запишется в 1 файл
  urls+="write-out = \"requestNumber_$i|%{http_code}|%{time_total}|%{time_connect}|%{time_pretransfer}|%{time_starttransfer}|%{time_namelookup}\n"
done

printf "%b" "$urls" | curl --connect-timeout 10 -Z --parallel-immediate -s --config - > "$dir_logs_and_responces/responses.log"

runTime=$(echo $EPOCHREALTIME - $start_time | bc)

for (( i=1; i<=totalRequests; i++ )); do
  if [ -f "$dir_logs_and_responces/response_$i.log" ]; then
      responce=$(< "$dir_logs_and_responces/response_$i.log")
      responce_without_line_break=$(printf '%s' "$responce" | tr -d '\r\n')
      safe_responce="${responce_without_line_break//\%/\\%}"
      sed -i 's%requestNumber_'"$i"'|%&'"$safe_responce"'|%g' "$dir_logs_and_responces/responses.log"
      rm "$dir_logs_and_responces/response_$i.log"
  fi
done

############ Дальше идёт обработка ответов ############

add_start_zero() {
  local input_num=$1
  if [ "$(echo "$input_num < 1" | bc)" -eq 1 ]; then
    echo "0${input_num}"
  else
    echo "$input_num"
  fi
}

calculation_of_statistics_responses() {
  line_num=0
  count_time_total_responses=()
  while IFS= read -r line; do
    ((line_num++))
    echo "Обработка строки $line_num"
    regex="(.*)\|(.*)\|(.*)\|(.*)\|(.*)\|(.*)\|(.*)"
    if [[ "$line" =~ $regex ]]; then
        http_code=${BASH_REMATCH[2]}
        time_total_one_request=${BASH_REMATCH[3]}
        time_connect_one_request=${BASH_REMATCH[4]}
        time_pretransfer_one_request=${BASH_REMATCH[5]}
        time_starttransfer_one_request=${BASH_REMATCH[6]}
        time_namelookup_one_request=${BASH_REMATCH[7]}

        if [ $http_code == 200 ]; then
          ((countSuccessRequests++))
          double_time_total_one_request=$(echo "0 + $time_total_one_request" | bc)

          if [ "$(echo "$double_time_total_one_request > $maxTotalTimeAllSuccessRequests" | bc)" -eq 1 ]; then
            maxTotalTimeAllSuccessRequests=$double_time_total_one_request
          fi

          if [ $minTotalTimeAllSuccessRequests == 0 ]; then
            minTotalTimeAllSuccessRequests=$double_time_total_one_request
          else
            if [ "$(echo "$minTotalTimeAllSuccessRequests > $double_time_total_one_request" | bc)" -eq 1 ]; then
              minTotalTimeAllSuccessRequests=$double_time_total_one_request
            fi
          fi

          int_time_total_one_request=$(awk -v num="$double_time_total_one_request" 'BEGIN {print int(num)}')
          if [[ -v count_time_total_responses["$int_time_total_one_request"] ]]; then
            ((count_time_total_responses["$int_time_total_one_request"]++))
          else
            count_time_total_responses["$int_time_total_one_request"]=1;
          fi

          totalTimeAllSuccessRequests=$(echo "$totalTimeAllSuccessRequests + $time_total_one_request" | bc)
          connectTimeAllSuccessRequest=$(echo "$connectTimeAllSuccessRequest + $time_connect_one_request" | bc)
          pretransferTimeAllSuccessRequest=$(echo "$pretransferTimeAllSuccessRequest + $time_pretransfer_one_request" | bc)
          starttransferTimeAllSuccessRequest=$(echo "$starttransferTimeAllSuccessRequest + $time_starttransfer_one_request" | bc)
          namelookupTimeAllSuccessRequest=$(echo "$namelookupTimeAllSuccessRequest + $time_namelookup_one_request" | bc)
        else
          echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ОШИБКА ОТВЕТА !!!!!!!!!! ОТВЕТ НЕ 200"
          echo "$line"
        fi
    fi
  done < "$dir_logs_and_responces/responses.log"

  echo -e "\n$countSuccessRequests параллельных запросов завершены успешно из $totalRequests за $(add_start_zero $runTime) сек \n"

  for key in "${!count_time_total_responses[@]}"; do
    echo "За $key целых секунд, пришло ответов: ${count_time_total_responses[$key]}"
  done

  if (( countSuccessRequests > 0 )); then
    echo ""
    echo "Минимальный total_time одного успешного запроса = $(add_start_zero $minTotalTimeAllSuccessRequests) сек"
    echo "Максимальный total_time одного успешного запроса = $(add_start_zero $maxTotalTimeAllSuccessRequests) сек"
    echo ""

    averageTotalTimeOneSuccessRequest=$(echo "scale=6; $totalTimeAllSuccessRequests / $countSuccessRequests" | bc)
    echo "Средний total_time одного успешного запроса = $(add_start_zero $averageTotalTimeOneSuccessRequest) сек"

    averageConnectTimeOneSuccessRequest=$(echo "scale=6; $connectTimeAllSuccessRequest / $countSuccessRequests" | bc)
    echo "Средний connect_time одного успешного запроса = $(add_start_zero $averageConnectTimeOneSuccessRequest) сек";

    averagePretransferTimeOneSuccessRequest=$(echo "scale=6; $pretransferTimeAllSuccessRequest / $countSuccessRequests" | bc)
    echo "Средний pretransfer_time одного успешного запроса = $(add_start_zero $averagePretransferTimeOneSuccessRequest) сек";

    averageStarttransferTimeOneSuccessRequest=$(echo "scale=6; $starttransferTimeAllSuccessRequest / $countSuccessRequests" | bc)
    echo "Средний starttransfer_time одного успешного запроса = $(add_start_zero $averageStarttransferTimeOneSuccessRequest) сек";

    averageNamelookupTimeOneSuccessRequest=$(echo "scale=6; $namelookupTimeAllSuccessRequest / $countSuccessRequests" | bc)
    echo "Средний namelookup_time одного успешного запроса = $(add_start_zero $averageNamelookupTimeOneSuccessRequest) сек";
  fi
}

calculation_of_statistics_responses

exit 0
