#!/bin/bash
export API_URL=http://127.0.0.1:8134

# 获取pending的交易哈希
pending_tx_hashes=($(./ckb-cli rpc get_raw_tx_pool --output-format json | jq -r '.pending[]'))

# 创建临时目录
tmp_dir=$(mktemp -d)
echo "tmp_dir: $tmp_dir"
echo "" # 在输出目录后加一个空行

# 如果没有pending交易
if [ ${#pending_tx_hashes[@]} -eq 0 ]; then
  echo "No pending transactions found."
  exit 0
fi

# 遍历每个交易哈希
for ((index = 0; index < ${#pending_tx_hashes[@]}; index++)); do
  tx_hash=${pending_tx_hashes[index]}
  (
    # 调用API获取交易详情并提取fee和weight，准备计算fee_rate
    response=$(curl -sS -X POST -H "Content-Type: application/json" -d "{\"id\": 1, \"jsonrpc\": \"2.0\", \"method\": \"get_pool_tx_detail_info\", \"params\": [\"$tx_hash\"]}" $API_URL)
    fee=$(echo $response | jq -r '.result.score_sortkey.fee')
    weight=$(echo $response | jq -r '.result.score_sortkey.weight')

    # 转换十六进制为十进制
    fee_decimal=$(printf "%d" "$fee")
    weight_decimal=$(printf "%d" "$weight")

    # 检查weight是否为零
    if [ "$weight_decimal" -eq 0 ]; then
      echo "Error: Weight is zero for transaction $tx_hash"
      exit 1
    fi

    # 计算fee_rate，保留整数
    fee_rate=$(echo "($fee_decimal * 1000) / $weight_decimal" | bc)

    # 将计算结果写入临时文件
    echo "tx_hash_$((index + 1)): $tx_hash" >"$tmp_dir/result_$index.txt"
    echo "fee_rate: $fee_rate shannons/kB fee: $fee_decimal weight: $weight_decimal" >>"$tmp_dir/result_$index.txt"
  ) &
done

# 等待所有后台进程完成
wait

# 按文件名排序并输出所有结果
for file in $(ls $tmp_dir | sort -V); do
  cat "$tmp_dir/$file"
  echo "" # 在每个结果块之后加一个空行以便区分
done

# 清理临时目录
rm -rf "$tmp_dir"
