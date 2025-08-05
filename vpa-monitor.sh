#!/bin/bash

# VPA 推薦值監控腳本
# 用法: ./vpa-monitor.sh [namespace] [vpa-name]
# ./vpa-monitor.sh default load-generator-vpa 10

NAMESPACE=${1:-"default"}
VPA_NAME=${2:-"load-generator-vpa"}
CHECK_INTERVAL=${3:-30}  # 檢查間隔（秒）

echo "開始監控 VPA: $VPA_NAME 在 namespace: $NAMESPACE"
echo "檢查間隔: ${CHECK_INTERVAL} 秒"
echo "按 Ctrl+C 停止監控"
echo "----------------------------------------"

# 創建臨時文件來存儲上一次的推薦值
TEMP_FILE="/tmp/vpa_recommendations_${VPA_NAME}.json"

# 獲取 VPA 推薦值
get_vpa_recommendations() {
    kubectl get vpa "$VPA_NAME" -n "$NAMESPACE" -o jsonpath='{.status.recommendation.containerRecommendations[0].target}' 2>/dev/null
}

# 獲取 Pod 當前 requests
get_pod_requests() {
    # 獲取 VPA 目標的 deployment 名稱
    local target_ref=$(kubectl get vpa "$VPA_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.targetRef.name}' 2>/dev/null)
    if [ -z "$target_ref" ]; then
        echo "無法獲取目標 deployment"
        return
    fi
    
    # 獲取該 deployment 下的所有 pods
    local pods_json=$(kubectl get pods -n "$NAMESPACE" -l app="$target_ref" -o json 2>/dev/null)
    if [ -z "$pods_json" ]; then
        echo "無法獲取 Pods"
        return
    fi
    
    # 解析所有 pods 的 requests
    local pod_count=$(echo "$pods_json" | jq '.items | length')
    local result=""
    
    for i in $(seq 0 $((pod_count - 1))); do
        local pod_name=$(echo "$pods_json" | jq -r ".items[$i].metadata.name")
        local pod_status=$(echo "$pods_json" | jq -r ".items[$i].status.phase")
        local requests=$(echo "$pods_json" | jq -r ".items[$i].spec.containers[0].resources.requests // {}")
        
        if [ "$result" != "" ]; then
            result="$result | "
        fi
        
        # 格式化顯示：Pod名稱(狀態): requests
        local formatted_requests=$(echo "$requests" | jq -r 'to_entries | map("\(.key): \(.value)") | join(", ")' 2>/dev/null)
        if [ "$formatted_requests" = "" ]; then
            formatted_requests="無 requests"
        fi
        
        result="$result$pod_name($pod_status): $formatted_requests"
    done
    
    echo "$result"
}

# 發送通知
send_notification() {
    local old_vpa_value="$1"
    local new_vpa_value="$2"
    local current_pod_requests="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "🔔 VPA 推薦值更新通知 - $timestamp"
    echo "VPA: $VPA_NAME"
    echo "舊推薦值: $old_vpa_value"
    echo "新推薦值: $new_vpa_value"
    echo "當前 Pod Requests: $current_pod_requests"
    echo "----------------------------------------"
    
    # 這裡可以添加其他通知方式，比如：
    # - 發送 Slack 通知
    # - 發送郵件
    # - 寫入日誌文件
    # - 觸發 webhook
}

# 格式化推薦值顯示
format_recommendations() {
    local recommendations="$1"
    if [ -z "$recommendations" ]; then
        echo "無推薦值"
        return
    fi
    
    # 解析 JSON 並格式化顯示
    echo "$recommendations" | jq -r 'to_entries | map("\(.key): \(.value)") | join(", ")' 2>/dev/null || echo "$recommendations"
}

# 顯示當前狀態
show_current_status() {
    local vpa_recommendations="$1"
    local pod_requests="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] 監控中..."
    echo "  VPA 推薦值: $(format_recommendations "$vpa_recommendations")"
    echo "  Pod Requests:"
    echo "$pod_requests" | tr '|' '\n' | sed 's/^/    /'
    echo "----------------------------------------"
}

# 主監控循環
while true; do
    current_vpa_recommendations=$(get_vpa_recommendations)
    current_pod_requests=$(get_pod_requests)
    
    if [ -f "$TEMP_FILE" ]; then
        previous_vpa_recommendations=$(cat "$TEMP_FILE")
        
        if [ "$current_vpa_recommendations" != "$previous_vpa_recommendations" ]; then
            send_notification "$(format_recommendations "$previous_vpa_recommendations")" "$(format_recommendations "$current_vpa_recommendations")" "$(format_recommendations "$current_pod_requests")"
        else
            # 顯示當前狀態（即使沒有變化）
            show_current_status "$current_vpa_recommendations" "$current_pod_requests"
        fi
    else
        echo "初始化監控"
        show_current_status "$current_vpa_recommendations" "$current_pod_requests"
    fi
    
    # 保存當前推薦值
    echo "$current_vpa_recommendations" > "$TEMP_FILE"
    
    sleep $CHECK_INTERVAL
done 