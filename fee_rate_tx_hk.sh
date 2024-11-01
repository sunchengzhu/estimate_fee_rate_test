#!/bin/bash
export URL=http://18.167.196.121:8121
export API_URL=https://testnet.ckbapp.dev

day=$(TZ='Asia/Shanghai' date "+%Y-%m-%d")
# Specifies the fee estimates algorithm. Current algorithms: ConfirmationFraction, WeightUnitsFlow.
algorithm=WeightUnitsFlow

estimate_fee_rate_hex=$(curl -sS -X POST -H "Content-Type: application/json" -d "{\"id\": 1, \"jsonrpc\": \"2.0\", \"method\": \"estimate_fee_rate\", \"params\": [\"no_priority\", true]}" $URL | jq -r '.result')
estimate_fee_rate=$(printf "%d" "$estimate_fee_rate_hex")
start_block_number=$(./ckb-cli rpc get_tip_header --output-format json | jq -r '.number')

tx_hash=$(echo "123" | ./ckb-cli wallet transfer --to-address ckt1qyqp0aph6x34apl808w5varrh9lupgzvhmys7pn63z --capacity 100.0 --from-account ckt1qyqp0aph6x34apl808w5varrh9lupgzvhmys7pn63z --fee-rate $estimate_fee_rate | sed 's/Password: //')

echo "Start Block Number: $start_block_number | estimate_fee_rate: $estimate_fee_rate | tx_hash: $tx_hash" >>"${algorithm}_fee_rate_${day}.log"

# 开始时间
start_time=$(date +%s)

# 循环查询交易状态
while true; do
    # 当前时间
    current_time=$(date +%s)

    # 计算已耗时
    elapsed_time=$((current_time - start_time))

    # 检查是否已超过100分钟（60000秒）
    if [[ $elapsed_time -ge 60000 ]]; then
        echo "Timeout after 100 minutes."
        exit 1
    fi

    # 调用 ckb-cli 获取交易状态
    response=$(./ckb-cli rpc get_transaction --hash "$tx_hash" --output-format json)

    # 解析交易状态
    tx_status=$(echo "$response" | jq -r '.tx_status.status')
    committed_block_number_hex=$(echo "$response" | jq -r '.tx_status.block_number')

    # 检查状态是否为committed
    if [[ "$tx_status" == "committed" ]]; then
        # 转换块号为十进制
        committed_block_number=$(printf "%d" "$committed_block_number_hex")

        # 结束循环
        break
    fi

    # 等待500毫秒
    sleep 0.5
done

# 结束时间
end_time=$(date +%s.%N)

# 计算并打印总耗时和上链所需区块数
duration=$(echo "$end_time - $start_time" | bc)
echo "Total blocks: $((committed_block_number - start_block_number)) | Total duration: ${duration}s | Committed Block Number: $committed_block_number | tx_hash: $tx_hash" >>"${algorithm}_fee_rate_${day}.log"
