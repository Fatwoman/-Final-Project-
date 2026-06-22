# 基於 RISC-V 核心之硬體亂數老虎機 SoC 設計與統計驗證

## 1. 專題名稱
RISC-V Slot Machine with Hardware RNG and UART Statistical Verification

## 2. 使用開發板
Digilent Basys 3

## 3. 使用工具版本
* **Vivado 版本：** [填入你的 Vivado 版本，例如 2023.2]
* **RISC-V Toolchain：** 機器碼透過 Memory Initialization File (.coe/.mem) 載入。
* **Python 環境：** Python 3.x (需安裝 pyserial, matplotlib)

## 4. 專案資料夾結構
* `/RISCV_V2.srcs/`：包含所有 Verilog 原始碼與 Constraint 檔。
  * `Top.v`：系統頂層模組。
  * `Address_Decoder.v`：Memory-Mapped I/O 記憶體映射解碼器。
  * `RNG.v` / `RNG_s1120455.v`：硬體線性回饋移位暫存器 (LFSR)。
  * `UART_TX.v`：修改過之串列通訊發送模組。
  * `Control_Unit_Top.v` 等：開源之 RISC-V 核心模組。
* `RISCV_V2.xpr`：Vivado 專案執行檔。
* `uart_plot.py`：[填入你的 Python 檔名] PC 端接收與畫圖腳本。

## 5. 如何產生 bitstream
1. 使用 Vivado 開啟 `RISCV_V2.xpr` 專案。
2. 點擊左側 Flow Navigator 中的 **Generate Bitstream**。
3. 等待合成 (Synthesis) 與實作 (Implementation) 跑完，即可產生 `.bit` 檔。

## 6. 如何載入或修改 RISC-V 程式
本專案的軟體控制邏輯已編譯為機器碼，並存放在 `[填入存放初始值的檔案名稱，例如 Data_Memory.v 或 .coe 檔]` 中。系統上電時會自動載入至 Instruction Memory 中執行。

## 7. 如何燒錄到 FPGA 開發板
1. 將 Basys 3 透過 Micro-USB 連接至電腦並開啟電源。
2. 於 Vivado 左下角點擊 **Open Hardware Manager** -> **Open Target** -> **Auto Connect**。
3. 點擊 **Program Device**，選擇剛剛生成的 `.bit` 檔進行燒錄。

## 8. 如何操作與測試
1. 上電後，七段顯示器歸零，LED 顯示初始總分。
2. 撥動 **SW[2:1]** 設定下注倍率 (x1, x2, x3, x5)。
3. 按壓 **BTND (U17)** 啟動老虎機，七段顯示器會快速跳動亂數。再次按壓即可停止並開獎。
4. 若中獎，LED 總分數會自動累加。
5. 電腦端執行 Python 腳本開啟 UART 監聽，切換 **SW15** 進入自動模式，系統將自動採集 50,000 局結果並於 PC 端繪製機率分佈圖。

## 9. 已知問題
* 尚未實作硬體中斷 (Interrupt)，目前 UART 軟硬體交握完全採用 Polling 機制，CPU 會在 `Wait_Tx_Ready` 狀態下空轉等待。
* 僅實作 UART 發送 (Tx)，尚無接收 (Rx) 雙向互動功能。

## 10. 外部來源與授權說明
* **RISC-V 核心：** 採用 https://github.com/Varunkumar0610/RISC-V-Single-Cycle-Core，基於 Apache License 2.0 授權使用。
* **UART 模組：** 參考 [nandland/UART](https://github.com/nandland/UART) 專案修改擴充。
