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
if [ -f "verboses.log" ]; then
  rm verboses.log
fi

urls=""

DELIM="::DATA_START::"
for (( i=1; i<=totalRequests; i++ )); do
  if (( i > 1 )); then
      urls+="--next\n"
  fi
  urls+="url = \"$url$i\"\n"
  urls+="verbose\n"
  urls+="data = \"id=$i\"\n"
  urls+="header = \"HeaderId: $i\"\n"
  urls+="output = \"$dir_logs_and_responces/response_$i.json\"\n"
  urls+="stderr = \"$dir_logs_and_responces/verboses.log\"\n"
  urls+="write-out = \"requestNumber=$i HTTP-код:%{http_code}|%{http_code}|%{time_total}|%{time_connect}|%{time_pretransfer}|%{time_starttransfer}|%{time_namelookup}\n"
done

printf "%b" "$urls" | curl --connect-timeout 10 -Z --parallel-immediate -s --config - > "$dir_logs_and_responces/logs.txt"

runTime=$(echo $EPOCHREALTIME - $start_time | bc)

line_num=0
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
          int_time_total_one_request=$(echo "0 + $time_total_one_request" | bc)

          if [ "$(echo "$int_time_total_one_request > $maxTotalTimeAllSuccessRequests" | bc)" -eq 1 ]; then
            maxTotalTimeAllSuccessRequests=$int_time_total_one_request
          fi

          if [ $minTotalTimeAllSuccessRequests == 0 ]; then
            minTotalTimeAllSuccessRequests=$int_time_total_one_request
          else
            if [ "$(echo "$minTotalTimeAllSuccessRequests > $int_time_total_one_request" | bc)" -eq 1 ]; then
              minTotalTimeAllSuccessRequests=$int_time_total_one_request
            fi
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
done < "$dir_logs_and_responces/logs.txt"

if [ -f "$dir_logs_and_responces/logs.txt" ]; then
  rm "$dir_logs_and_responces/logs.txt"
fi

if [ -f "responses.json" ]; then
  rm responses.json
fi

for (( i=1; i<=totalRequests; i++ )); do
  if [ -f "$dir_logs_and_responces/response_$i.json" ]; then
      cat "$dir_logs_and_responces/response_$i.json" >> "$dir_logs_and_responces/responses.json"
      echo "" >> "$dir_logs_and_responces/responses.json"
      rm "$dir_logs_and_responces/response_$i.json"
  fi
done

echo -e "\n$countSuccessRequests параллельных запросов завершены успешно из $totalRequests за $runTime сек \n"

if (( countSuccessRequests > 0 )); then
  echo "Минимальный total_time одного успешного запроса = $minTotalTimeAllSuccessRequests"
  echo "Максимальный total_time одного успешного запроса = $maxTotalTimeAllSuccessRequests"
  echo ""

  averageTotalTimeOneSuccessRequest=$(echo "scale=6; $totalTimeAllSuccessRequests / $countSuccessRequests" | bc)
  echo "Средний total_time одного успешного запроса = $averageTotalTimeOneSuccessRequest"

  averageConnectTimeOneSuccessRequest=$(echo "scale=6; $connectTimeAllSuccessRequest / $countSuccessRequests" | bc)
  echo "Средний connect_time одного успешного запроса = $averageConnectTimeOneSuccessRequest";

  averagePretransferTimeOneSuccessRequest=$(echo "scale=6; $pretransferTimeAllSuccessRequest / $countSuccessRequests" | bc)
  echo "Средний pretransfer_time одного успешного запроса = $averagePretransferTimeOneSuccessRequest";

  averageStarttransferTimeOneSuccessRequest=$(echo "scale=6; $starttransferTimeAllSuccessRequest / $countSuccessRequests" | bc)
  echo "Средний starttransfer_time одного успешного запроса = $averageStarttransferTimeOneSuccessRequest";

  averageNamelookupTimeOneSuccessRequest=$(echo "scale=6; $namelookupTimeAllSuccessRequest / $countSuccessRequests" | bc)
  echo "Средний namelookup_time одного успешного запроса = $averageNamelookupTimeOneSuccessRequest";
fi

exit 0
