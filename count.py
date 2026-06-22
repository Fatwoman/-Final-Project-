import serial
import pandas as pd
import matplotlib.pyplot as plt
import re
from collections import Counter  # 新增：用於快速統計重複元素的計數引擎

# 1. 設定串口 (請確保與你的 COM3 一致)
ser = serial.Serial('COM3', 115200, timeout=1)
data_list = []
MAX_GAMES = 50000  # 設定收集目標局數
games_collected = 0

# 新增：初始化中獎類型的統計計數器
award_stats = {
    "四個一樣 (x50)": 0,
    "三個一樣 (x20)": 0,
    "兩個一樣 (x10)": 0,
    "沒中獎 (x0)": 0
}

print(f"開始收集數據中... 目標：{MAX_GAMES} 局")
print("請確保 Switch 15 已往上撥(自動模式)，並按下 U17 啟動！")

try:
    while games_collected < MAX_GAMES:
        line = ser.readline().decode('utf-8', errors='ignore').strip()
        
        # 匹配 4 個逗號分隔的數字
        match = re.findall(r'\[(\d),(\d),(\d),(\d),', line)

        if match:
            numbers = [int(n) for n in match[0]]
            data_list.extend(numbers)  # 保持原本的單個數字記錄，用來畫 RNG 公平性圖
            games_collected += 1
            
            # --- 新增：判定該局中獎類型 ---
            num_counts = Counter(numbers)       # 統計每個數字出現幾次，例如 [7, 7, 7, 2] -> {7: 3, 2: 1}
            max_repeat = max(num_counts.values()) # 找出最大重複次數
            
            if max_repeat == 4:
                award_stats["四個一樣 (x50)"] += 1
            elif max_repeat == 3:
                award_stats["三個一樣 (x20)"] += 1
            elif max_repeat == 2:
                award_stats["兩個一樣 (x10)"] += 1
            else:
                award_stats["沒中獎 (x0)"] += 1
            
            print(f"收到第 {games_collected}/{MAX_GAMES} 局: {match[0]}")

except KeyboardInterrupt:
    print("\n收到中斷指令，提前停止收集並開始繪圖...")

finally:
    # 確保通訊埠安全關閉
    ser.close()

# ==========================================================
# 2. 資料列印文字報告 (可直接複製貼進期末報告文字敘述)
# ==========================================================
print("\n" + "="*45)
print(" 🎰  RISC-V 老虎機大樣本中獎機率統計報告  🎰")
print("="*45)
print(f"總測試局數: {games_collected} 局 (共 {len(data_list)} 個亂數樣本)")
for award, count in award_stats.items():
    percentage = (count / games_collected) * 100 if games_collected > 0 else 0
    print(f"  🔹 {award}: {count} 次 ({percentage:.2f}%)")
print("="*45)

# ==========================================================
# 3. 雙子圖並行繪製 (左圖：RNG 公平性 / 右圖：中獎率統計)
# ==========================================================
print("\n資料收集完畢，正在計算分佈並繪圖...")

plt.figure(figsize=(15, 6)) # 開啟一個寬螢幕畫布

# 【左子圖】：原本的 0-9 亂數公平性直方圖
plt.subplot(1, 2, 1) # 1行2列的第1張圖
df_rng = pd.Series(data_list)
counts_rng = df_rng.value_counts().sort_index()
bars_rng = counts_rng.plot(kind='bar', color='skyblue', edgecolor='black')

for bar in bars_rng.patches:
    plt.annotate(str(bar.get_height()), 
                 (bar.get_x() + bar.get_width() / 2., bar.get_height()), 
                 ha='center', va='bottom', fontsize=9)

plt.title(f'RNG Fairness Verification (Total Numbers: {len(data_list)})')
plt.xlabel('Number (0-9)')
plt.ylabel('Frequency')
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.xticks(rotation=0)

# 【右子圖】：新增的老虎機中獎類型統計圖
plt.subplot(1, 2, 2) # 1行2列的第2張圖
df_award = pd.Series(award_stats)
bars_award = df_award.plot(kind='bar', color='lightgreen', edgecolor='black')

for bar in bars_award.patches:
    plt.annotate(str(bar.get_height()), 
                 (bar.get_x() + bar.get_width() / 2., bar.get_height()), 
                 ha='center', va='bottom', fontsize=10)

plt.title(f'Slot Machine Jackpot Statistics (Total Games: {games_collected})')
plt.xlabel('Award Type')
plt.ylabel('Games Count')
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.xticks(rotation=15) # 稍微旋轉 15 度，防止標籤字體重疊

plt.tight_layout() # 自動調整間距防邊界重疊
plt.show()