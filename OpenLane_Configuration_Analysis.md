# BẢNG THỐNG KÊ CẤU HÌNH OPENLANE DESIGN FLOW

## 1. SYNTHESIS (Tổng hợp)

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 1 | `SYNTH_STRATEGY` | "AREA 0" | Chiến lược tổng hợp tối ưu diện tích (AREA) với mức độ 0 |
| 2 | `SYNTH_BUFFERING` | 1 | Bật chế độ chèn buffer để cải thiện timing |
| 3 | `SYNTH_SIZING` | 1 | Bật tối ưu kích thước gate để cải thiện timing/power |
| 4 | `SYNTH_NO_FLAT` | 1 | Không flatten hierarchy, giữ nguyên cấu trúc thiết kế |
| 5 | `SYNTH_SHARE_RESOURCES` | 1 | Chia sẻ tài nguyên logic để giảm diện tích |
| 6 | `MAX_FANOUT_CONSTRAINT` | 8 | Giới hạn fanout tối đa của một net |
| 7 | `MAX_TRANSITION_CONSTRAINT` | 0.75 | Thời gian chuyển đổi tối đa (ns) |
| 8 | `SYNTH_DRIVING_CELL` | "sky130_fd_sc_hd__inv_2" | Cell driver để tính toán input delay |

## 2. STATIC TIMING ANALYSIS (STA)

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 9 | `CLOCK_PERIOD` | 20 ns | Chu kỳ clock mục tiêu (override từ 10ns gốc) |
| 10 | `CLOCK_PORT` | "clk" | Tên port clock chính |
| 11 | `PNR_SDC_FILE` | "dir::src/counter_test.sdc" | File constraints cho P&R |
| 12 | `SIGNOFF_SDC_FILE` | "dir::src/counter_test.sdc" | File constraints cho signoff |

## 3. FLOORPLAN

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 13 | `FP_CORE_UTIL` | 50% | Tỷ lệ sử dụng core area (override từ 30%) |
| 14 | `FP_ASPECT_RATIO` | 1 | Tỷ lệ khung hình core (1 = hình vuông) |
| 15 | `FP_SIZING` | "absolute" | Phương pháp định kích thước (absolute/relative) |
| 16 | `DIE_AREA` | "0 0 100 100" | Kích thước die area (μm) |
| 17 | `FP_PIN_ORDER_CFG` | "dir::pin_order.cfg" | File định nghĩa thứ tự pin |
| 18 | `FP_PDN_VOFFSET` | 16.32 | Offset dọc của power rail |
| 19 | `FP_PDN_HOFFSET` | 16.65 | Offset ngang của power rail |
| 20 | `FP_PDN_VWIDTH` | 1.6 | Độ rộng power rail dọc |
| 21 | `FP_PDN_HWIDTH` | 1.6 | Độ rộng power rail ngang |
| 22 | `FP_PDN_VPITCH` | 180 | Khoảng cách power rail dọc |
| 23 | `FP_PDN_HPITCH` | 180 | Khoảng cách power rail ngang |
| 24 | `FP_PDN_SKIPTRIM` | true | Bỏ qua trim power rail |

## 4. PLACEMENT

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 25 | `PL_TARGET_DENSITY` | 0.60 | Mật độ placement mục tiêu (60%) |
| 26 | `PL_RESIZER_TIMING_OPTIMIZATIONS` | true | Bật tối ưu timing trong placement |
| 27 | `PL_RESIZER_DESIGN_OPTIMIZATIONS` | true | Bật tối ưu thiết kế trong placement |
| 28 | `PL_RESIZER_BUFFER_INPUT_PORTS` | true | Buffer cho input ports |
| 29 | `PL_RESIZER_BUFFER_OUTPUT_PORTS` | true | Buffer cho output ports |
| 30 | `PL_RESIZER_HOLD_SLACK_MARGIN` | 0.2 | Margin cho hold slack (ns) |
| 31 | `PL_RESIZER_ALLOW_SETUP_VIOS` | true | Cho phép vi phạm setup tạm thời |
| 32 | `PL_RESIZER_HOLD_MAX_BUFFER_PERCENT` | 40% | Tỷ lệ buffer tối đa cho hold fixing |

## 5. CLOCK TREE SYNTHESIS (CTS)

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 33 | `CLOCK_TREE_SYNTH` | true | Bật clock tree synthesis |
| 34 | `CTS_STRATEGY` | "4" | Chiến lược CTS (4 = H-tree balanced) |
| 35 | `CTS_TARGET_SKEW` | 50 | Clock skew mục tiêu (ps) |
| 36 | `CTS_SINK_CLUSTERING_SIZE` | 15 | Kích thước cluster cho clock sink |
| 37 | `CTS_SINK_CLUSTERING_MAX_DIAMETER` | 50 | Đường kính tối đa của cluster |
| 38 | `CTS_CLK_MAX_WIRE_LENGTH` | 50 | Độ dài dây clock tối đa |
| 39 | `CTS_CLK_BUFFER_LIST` | ["clkbuf_1", "clkbuf_2", "clkbuf_4"] | Danh sách buffer cho clock tree |
| 40 | `CTS_DISABLE_POST_PROCESSING` | false | Bật post-processing sau CTS |
| 41 | `CTS_RUN_POST_CTS_RESIZER_TIMING` | true | Chạy timing optimization sau CTS |

## 6. ROUTING

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 42 | `GRT_ADJUSTMENT` | 0.10 | Điều chỉnh routing congestion (10%) |
| 43 | `GRT_ALLOW_CONGESTION` | false | Không cho phép congestion |
| 44 | `GRT_REPAIR_ANTENNAS` | true | Sửa antenna violations |
| 45 | `DRT_OPT_ITERS` | 32 | Số iterations cho detailed routing |
| 46 | `ROUTING_CORES` | 4 | Số cores CPU cho routing |
| 47 | `DIODE_ON_PORTS` | "in" | Đặt diode trên input ports |

## 7. SIGNOFF

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 48 | `RUN_LEC` | true | Chạy Logic Equivalence Check |
| 49 | `LEC_ENABLE` | true | Bật LEC verification |
| 50 | `RUN_MAGIC_DRC` | true | Chạy DRC với Magic tool |
| 51 | `RUN_MAGIC_LVS` | true | Chạy LVS với Magic tool |
| 52 | `RUN_KLAYOUT_XOR` | false | Không chạy XOR check với KLayout |
| 53 | `RUN_KLAYOUT_DRC` | false | Không chạy DRC với KLayout |
| 54 | `MAGIC_EXT_USE_GDS` | false | Không dùng GDS cho extraction |
| 55 | `MAGIC_ZEROIZE_ORIGIN` | true | Đặt origin về (0,0) |
| 56 | `MAGIC_GENERATE_LEF` | true | Tạo file LEF |
| 57 | `MAGIC_GENERATE_GDS` | true | Tạo file GDS |
| 58 | `MAGIC_WRITE_FULL_LEF` | true | Ghi LEF đầy đủ |

## 8. TECHNOLOGY-SPECIFIC CONFIGS (PDK sky130)

| STT | Cấu hình | Giá trị | Ý nghĩa |
|-----|----------|---------|---------|
| 59 | `pdk::sky130*::FP_CORE_UTIL` | 50% | Core utilization cho sky130 PDK |
| 60 | `pdk::sky130*::CLOCK_PERIOD` | 20 ns | Clock period mặc định cho sky130 |
| 61 | `scl::sky130_fd_sc_hs::CLOCK_PERIOD` | 15 ns | Clock period cho high-speed library |
| 62 | `scl::sky130_fd_sc_ls::MAX_FANOUT_CONSTRAINT` | 6 | Max fanout cho low-speed library |

## KẾT QUẢ THỐNG KÊ CHÍNH

| Thông số | Giá trị | Đơn vị |
|----------|---------|---------|
| **Synthesis** | | |
| Cell count | 14 | cells |
| **Floorplan** | | |
| Die Area | 10,000 | μm² |
| Core Area | 6,761.48 | μm² |
| Core Utilization | 5.88% | % |
| **Timing** | | |
| WNS (Worst Negative Slack) | 0.0 | ns |
| TNS (Total Negative Slack) | 0.0 | ns |
| Critical Path | 0.84 | ns |
| **Routing** | | |
| Wire Length | 571 | μm |
| Vias | 150 | count |
| Violations | 0 | count |
| **Power** | | |
| Typical Internal | 84.0 | μW |
| Typical Switching | 22.7 | μW |
| Typical Leakage | 0.019 | μW |
| **Runtime** | | |
| Total Runtime | 51 | seconds |
| Routing Runtime | 36 | seconds |
