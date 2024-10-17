#!/bin/bash

URL="http://127.0.0.1:8134"
export API_URL=$URL
PRIORITY_LEVELS=("no_priority" "low_priority" "medium_priority" "high_priority")
INTERVAL=10

while true; do
    echo "$(TZ='Asia/Shanghai' date "+%Y-%m-%d %H:%M:%S") block_number: $(./ckb-cli rpc get_tip_header --output-format json | jq -r .number)"
    for PRIORITY in "${PRIORITY_LEVELS[@]}"; do
        # 执行第一次请求，参数根据循环中的优先级变化
        result=$(curl -sS -X POST $URL \
            -H "Content-Type: application/json" \
            -d "{
      \"id\": 1,
      \"jsonrpc\": \"2.0\",
      \"method\": \"estimate_fee_rate\",
      \"params\": [\"$PRIORITY\", false]
    }" | jq -r '.result' | sed 's/^0x//')

        # 判断第一次请求是否成功转换（即变量是否为有效的十六进制数）
        if [[ "$result" =~ ^[0-9a-fA-F]+$ ]]; then
            # 如果是有效的十六进制数，转换并输出
            fee_rate=$((16#$result))
            echo "$PRIORITY fee_rate: $fee_rate"
        else
            # 如果结果无效，则改变参数为true并再次执行
            fallback_fee_rate=$(curl -sS -X POST $URL \
                -H "Content-Type: application/json" \
                -d "{
          \"id\": 1,
          \"jsonrpc\": \"2.0\",
          \"method\": \"estimate_fee_rate\",
          \"params\": [\"$PRIORITY\", true]
        }" | jq -r '.result' | sed 's/^0x//')

            # 检查第二次请求的结果
            if [[ "$fallback_fee_rate" =~ ^[0-9a-fA-F]+$ ]]; then
                # 如果是有效的十六进制数，转换并输出
                fallback_fee_rate=$((16#$fallback_fee_rate))
                echo "$PRIORITY fallback fee_rate: $fallback_fee_rate"
            else
                echo "Failed to get a valid response even after parameter change for $PRIORITY"
            fi
        fi
    done
    echo
    sleep $INTERVAL

done
