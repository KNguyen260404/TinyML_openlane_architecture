# TinyML OpenLane Architecture

![OpenLane Logo](https://openlane.readthedocs.io/en/latest/_images/openlane_logo.png)

## 1. Giới thiệu về OpenLane Architecture

OpenLane là một hệ thống thiết kế vi mạch tự động (ASIC Flow) mã nguồn mở, dựa trên các công cụ EDA nguồn mở như OpenROAD, Magic, Netgen, KLayout, v.v. OpenLane giúp tự động hóa toàn bộ quy trình thiết kế từ RTL đến GDSII, bao gồm các bước như tổng hợp, floorplanning, placement, CTS, routing, DRC/LVS, và xuất layout cuối cùng.

Quy trình OpenLane giúp các nhà thiết kế nhanh chóng hiện thực hóa ý tưởng phần cứng thành silicon, giảm chi phí và rào cản tiếp cận công nghệ sản xuất chip.

<p align="center">
  <img src="https://openlane.readthedocs.io/en/latest/_images/flow.png" alt="OpenLane Flow" width="700"/>
</p>

## 2. Thông số dự án TinyML

- **Tên dự án:** TinyML_openlane_architecture
- **Mục tiêu:** Thiết kế và tổng hợp một mô hình Random Forest cho ứng dụng phát hiện tấn công trên bus CAN, sử dụng flow OpenLane.
- **Công nghệ:** Sky130 (SkyWater 130nm Open PDK)
- **Số lượng cây quyết định (Decision Trees):** 21
- **Độ sâu pipeline:** 10
- **Kích thước node:** 120 bit
- **Số lượng node lớn nhất mỗi cây:** 512
- **Các file chính:**
  - `src/Random_forest_top_ver2.v`: Mô tả phần cứng top-level của mô hình Random Forest
  - `src/tree_rom_*.v`: Các ROM chứa trọng số cho từng cây quyết định
  - `src/Random_forest_top_ver2.sdc`: Ràng buộc thời gian
- **Các bước thực hiện:**
  1. Viết RTL Verilog cho mô hình Random Forest
  2. Thiết lập các file cấu hình cho OpenLane
  3. Chạy flow OpenLane để tổng hợp, layout, kiểm tra DRC/LVS
  4. Xuất file layout GDSII

## 3. Hình ảnh layout GDSII của chip

<p align="center">
  <img src="runs/RUN_2025.05.08_06.07.33/results/final/Random_forest_top_ver2.gdsii.png" alt="GDSII Layout" width="600"/>
</p>

> *Hình ảnh trên là layout cuối cùng của chip sau khi hoàn thành flow OpenLane. File GDSII có thể được xem bằng KLayout hoặc Magic.*

---

### Tham khảo
- [OpenLane Documentation](https://openlane.readthedocs.io/en/latest/)
- [SkyWater PDK](https://skywater-pdk.readthedocs.io/en/main/)
- [OpenROAD Project](https://theopenroadproject.org/)