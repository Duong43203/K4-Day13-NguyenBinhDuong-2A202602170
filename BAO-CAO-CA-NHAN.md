# Báo cáo cá nhân — Day 13: LiDAR 3D Object và PointPillars

> Mẫu dành cho một người thực hiện theo yêu cầu bài cá nhân. Những chỗ `[điền]` cần thay bằng thông tin và kết quả thực tế. Đây chưa phải báo cáo đã hoàn thành. Không sửa mẫu trong gói Student đã có manifest; điền vào bản riêng ở ngoài gói. Bản chứa danh tính hoặc bằng chứng Robotaxi chỉ nộp trong kênh riêng được cấp.

## Hướng dẫn thực hiện trước khi viết

1. Chuẩn bị gói Student đã giải nén, Docker chạy Linux containers và Python 3.10+. Chọn gói amd64 cho máy Intel/AMD, arm64 cho Apple Silicon. Repo source hiện tại không có image archive và manifest của gói chạy; lệnh `run` cần gói ZIP đầy đủ.
2. Trong PowerShell tại thư mục gói đã giải nén, kiểm `docker info` và `py -3 --version`. Chạy một lệnh:

   ```powershell
   py -3 student-bundle.py run --bundle . --out ..\ket-qua-ca-nhan-01
   ```

   Thư mục output phải mới hoặc trống, nằm ngoài gói. Nếu máy không có `py`, dùng `python` sau khi kiểm phiên bản. Không cần tự build image hoặc train model để làm bài.
3. Kiểm `smoke.json` có `status: passed`. Nếu thất bại, giữ log và ghi rõ phần chưa chạy được; không tự điền số liệu thành công.
4. Đọc `run-A/B/C/summary.csv`, các file `boxes-*.json`, `side-*.png` và `qc-cases/manifest.json`. Lấy số hộp và mean_z từ CSV; đếm từng class từ trường `label` trong JSON. Nếu không có hộp, mean_z để trống và ghi không xác định.
5. Viết phần A/B, B/C và ca QC bằng bằng chứng cụ thể. Có thể đưa ba ảnh Side KITTI và ba ảnh QC vào phụ lục với tên file, chú thích và nguồn dữ liệu.
6. Nếu được giao job CVAT/portal, làm phần nguồn → Save → v1 → feedback → sửa nguồn/Save → v2; ghi các trường hợp tiêu biểu ở mục 5. Làm cá nhân không đồng nghĩa tự QC bài mình. Nếu phiên bản bài cá nhân không giao portal/QC, ghi rõ không thuộc phạm vi được giao.
7. Xóa phần hướng dẫn này khỏi bản nộp nếu giảng viên chỉ yêu cầu nội dung báo cáo. Độ dài gợi ý 6–8 trang chưa gồm phụ lục; đây là đề xuất trình bày, không phải quy định số trang của repo.

## 1. Thông tin và mục tiêu

- Họ tên: Nguyễn Bình Dương
- MSSV/lớp: 2A202602170/lab304
- Ngày thực hiện: 2/10/2026
- Hình thức: Cá nhân; tự thực hiện vận hành, kiểm cấu hình, phân tích hình học và ghi báo cáo.
- Phạm vi thực tế: [A/B/C và ca QC / có thêm chỉnh cuboid và QC trên portal]
- Trạng thái thực hiện: [tự chạy trên máy cá nhân / tự thao tác trên máy LC / chỉ phân tích kết quả được cung cấp]

Mục tiêu của bài là sử dụng PointPillars pretrained KITTI để tạo pre-label cho một point cloud, khảo sát ảnh hưởng của delta và kích thước pillar, đồng thời nhận biết lỗi chuyển tọa độ ở mức pipeline và mức đối tượng. Pre-label là gợi ý cần kiểm tra, không phải nhãn chuẩn. Bài sử dụng checkpoint có sẵn, không huấn luyện mô hình mới.

## 2. Dữ liệu, môi trường và mã nguồn

### 2.1 Dữ liệu

Đầu vào Student là mẫu KITTI/MMDetection3D demo 000008 được chuyển thành `demo.pcd`, gồm 17.238 điểm. Converter giữ x/y và thứ tự điểm, cộng 1,73 m vào z, bỏ reflectance gốc và ghi trường RGB bằng 0. PCD có các trường `x y z rgb`, mỗi record 16 byte. Phép dịch này phục vụ bài thực hành tọa độ; không xác nhận mặt đường tại mọi vị trí có z bằng 0.

Gói Student không có ảnh camera hoặc ground truth. Dữ liệu Robotaxi trong CVAT là phần riêng, không phải đầu vào của thí nghiệm KITTI này.

- Nguồn và thay đổi: `data/ATTRIBUTION.md`, `data/provenance.json`.
- PCD SHA256 đối chiếu: `3b5ea3da13e2b19149cab6a8d521c2ca55f2df93f026b5a3f8c273ce70645d60`.
- Giữ ghi nguồn và giấy phép dữ liệu được cung cấp cùng gói.

### 2.2 Môi trường đã dùng

| Thông tin | Giá trị thực tế / nguồn kiểm tra |
| --- | --- |
| Hệ điều hành, CPU, RAM máy | [điền] |
| Architecture Docker | [amd64/arm64; từ docker info] |
| Phiên bản Python và Docker | [điền] |
| Gói Student / tên ZIP | [điền] |
| Image tag và image ID | [manifest.json hoặc smoke.json] |
| Repo revision, working_tree_dirty | [manifest.json hoặc smoke.json] |
| Checkpoint path và SHA256 | [manifest.json hoặc smoke.json] |
| Input/frame và hash | [manifest.json hoặc smoke.json] |
| Thời điểm, trạng thái chạy | [điền; smoke.json ghi thời gian UTC] |

Runner giới hạn mỗi container ở 4 CPU và 4 GB RAM, chạy tuần tự và tắt mạng khi inference. Đây là giới hạn cấp cho container, không phải số RAM thực đo hoặc RAM tối thiểu của máy.

### 2.3 Vai trò các thành phần

| Thành phần | Chức năng trong bài |
| --- | --- |
| `bundle/student-bundle.py` | Kiểm manifest/hash/kiến trúc, load image, chạy A/B/C và helper QC, ghi smoke.json |
| `practice/preannotate.py` | Đọc PCD, ước lượng ground, chuyển tọa độ, inference, hậu xử lý, xuất JSON/PNG/CSV |
| `practice/pipeline-qc-cases.py` | Tạo ba ca QC có kiểm soát từ prediction B; không chạy model |
| `practice/Dockerfile` và `practice/patches/` | Chuẩn bị môi trường PointPillars CPU, voxel op C++ CPU và NMS CPU |
| `bundle/prepare-kitti-demo.py` | Tái tạo PCD từ file nguồn đúng hash và ghi provenance |
| Các file test | Kiểm hợp đồng runner/converter/helper; test dùng mock Docker không chứng minh inference thật |
| Guideline và rubric | Quy tắc kiểm cuboid, viết feedback và tự kiểm bằng chứng |

Không cần chép toàn bộ mã nguồn vào báo cáo. Chỉ giải thích các bước có liên quan đến thí nghiệm và dẫn tên file/hàm.

## 3. Phương pháp và thiết kế thí nghiệm

Luồng xử lý: PCD → đọc xyz → ước lượng z_ground → chuyển sang hệ model và lọc ROI → inference PointPillars CPU → đổi hộp về hệ nguồn/hậu xử lý → xuất JSON, ảnh Side và CSV.

`estimate_ground()` chọn tâm bin đông điểm nhất trong histogram z, độ rộng bin mặc định 0,05 m. Đây là ước lượng từ scan, không phải bản đồ mặt đường cục bộ đã xác minh.

```text
z_model  = z_source - z_ground - delta
z_source = z_model  + z_ground + delta
```

Với output KITTI, script còn chuyển bottom-z thành center-z bằng cách cộng nửa chiều cao trước phép chuyển ngược, và đổi quy ước yaw. JSON đã ở hệ nguồn nên không cộng delta lần nữa.

PCD không có intensity thật. Adapter KITTI dùng kênh hằng 0 cho lượt giữ vehicles và 0,7 cho lượt giữ pedestrian/two-wheels, sau đó gộp/hậu xử lý. Các hằng số này không phục hồi reflectance bị bỏ.

| Lượt | Delta (m) | Pillar XY (m) | So sánh để khảo sát |
| --- | ---: | ---: | --- |
| A | 0 | 0.16 | A/B: ảnh hưởng đổi delta trước inference |
| B | 1.73 | 0.16 | Mốc đối chiếu, nguồn tạo ca QC |
| C | 1.73 | 0.32 | B/C: ảnh hưởng đổi kích thước pillar |

Giữ nguyên input, checkpoint, score threshold 0,3 và front ROI. ROI của preset KITTI trong hệ model là x ∈ (0; 69,12), y ∈ (-39,68; 39,68), z ∈ (-3; 1), đơn vị mét. Runner không bật full-scene. Pillar XY là kích thước ô gom điểm trên mặt phẳng x-y, không phải kích thước cuboid. C dùng lại checkpoint, không được train lại cho pillar mới.

Không dùng A/C để quy kết ảnh hưởng của một biến vì cả delta và pillar đều đổi. A vẫn trừ z_ground dù delta bằng 0.

## 4. Kết quả và phân tích

### 4.1 Ba lượt inference

| Lượt | n_boxes từ CSV | mean_z từ CSV (m) | vehicles | pedestrian | two-wheels | File/vùng quan sát |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| A | [điền] | [điền] | [điền] | [điền] | [điền] | [điền] |
| B | [điền] | [điền] | [điền] | [điền] | [điền] | [điền] |
| C | [điền] | [điền] | [điền] | [điền] | [điền] | [điền] |

**A/B:** A có [điền] hộp và B có [điền] hộp. Tại vùng x khoảng [điền] m trong file [điền], em quan sát [điền]. JSON cho thấy [class/tâm/kích thước thực tế]. Vì chỉ delta thay đổi, kết quả cho thấy [nhận xét trong phạm vi thí nghiệm]. Model được chạy lại trên input đã đổi z nên không yêu cầu mọi hộp A/B lệch nhau đúng 1,73 m. Điều chưa đủ cơ sở kết luận: [điền].

**B/C:** B có [điền] hộp và C có [điền] hộp. Khi cạnh pillar tăng từ 0,16 m lên 0,32 m, em quan sát [điền] trong file/vùng [điền]. Có thể thảo luận thay đổi độ phân giải biểu diễn, nhưng phải tách giả thuyết giải thích khỏi điều đã quan sát. Kết quả chưa chứng minh cấu hình nào chính xác hơn khi chưa có reference được duyệt.

mean_z chỉ là trung bình cao độ tâm các hộp được dự đoán; hai lượt có thể dự đoán các đối tượng khác nhau. Nhiều hộp hơn, score cao hơn hoặc mean_z thấp hơn không tự chứng minh tốt hơn.

### 4.2 Các ca QC có kiểm soát

Lấy N từ số hộp B và H từ `height_offset_m` trong `qc-cases/manifest.json`, với H = z_ground + delta. Helper sao chép B rồi thay đổi có chủ đích; tên `case-correct` chỉ là bản giữ nguyên chuyển đổi nguồn, không phải nhãn đúng.

| Ca | Số hộp bị thay đổi z so với B | Thay đổi z | Những trường còn giữ | Quyết định |
| --- | --- | --- | --- | --- |
| case-correct | 0/N | 0 | Toàn bộ nội dung boxes | Tiếp tục kiểm hình học; chưa chứng nhận prediction đúng |
| case-batch-z | N/N | -H m | class, x/y, kích thước, yaw, score | Dừng chỉnh tay cả batch, kiểm transform/pipeline và yêu cầu prediction được tạo lại đúng |
| case-one-box-z | 1/N | -H m ở hộp đầu tiên | Các hộp khác và trường ngoài z | Kiểm đối tượng qua nhiều view; không kết luận lỗi pipeline chỉ từ một hộp |

- N thực tế: [điền]
- z_ground thực tế, delta, H: [điền]
- Tên JSON/ảnh và vị trí làm bằng chứng: [điền]
- Quan sát thực tế giữa ba ca: [điền]
- Không import ca training_only hoặc prediction KITTI demo vào job Robotaxi.

### 4.3 Giới hạn

Thí nghiệm dùng một frame đã chuyển đổi và không có ground truth trong gói. Reflectance thật đã bị bỏ; adapter dùng kênh hằng. Checkpoint và dữ liệu bài sửa Robotaxi có khác biệt miền dữ liệu. C thay pillar nhưng giữ checkpoint cũ. Ảnh Side của script là hình x-z đơn giản, bỏ thông tin y và vẽ hình chữ nhật theo length/height, không phải phép chiếu cuboid có xét yaw đầy đủ. Vì vậy không dùng riêng ảnh này để chốt yaw, ranh giới hoặc độ đúng từng hộp. Không tính accuracy/mAP/IoU khi chưa có nhãn reference và quy trình đánh giá phù hợp.

## 5. Chỉnh cuboid và QC trên CVAT/portal, nếu được giao

Nếu chưa thực hiện, ghi rõ chưa thực hiện. Nếu không thuộc phiên bản bài cá nhân được giao, ghi rõ phạm vi đó. Không biến mô tả quy trình trong tài liệu thành kết quả của bản thân.

Các yếu tố kiểm: class, tâm, dài/rộng/cao, yaw/đầu xe, đáy theo mặt đường cục bộ, hộp thiếu/thừa. Kiểm góc Trên, Bên, Trước, góc tự do và ảnh camera cùng frame khi có. Schema gồm vehicles, two-wheels, pedestrian, Animal, Obstacle; model chỉ dự đoán ba class đầu.

| Job/frame | ID hộp hoặc vùng | Vấn đề ở v1 | Góc nhìn/bằng chứng | Sửa ở nguồn / lý do giữ | Trạng thái v2 hoặc đang chờ |
| --- | --- | --- | --- | --- | --- |
| [điền] | [điền] | [điền] | [điền] | [điền] | [điền] |

| Job QC | ID/vùng | Loại lỗi | Bằng chứng, điều chưa chắc | Đề xuất | Đã nộp feedback? |
| --- | --- | --- | --- | --- | --- |
| [điền] | [điền] | [điền] | [điền] | [điền] | [điền] |

- Job đã rà toàn frame / một phần: [điền số lượng thực tế]
- Job đã nộp v1: [điền]
- Lượt QC đã nộp feedback: [điền]
- Job đã phản hồi/v2, job đang chờ: [điền]
- Một trường hợp tiếp thu hoặc chưa đồng ý feedback và bằng chứng: [điền]

Không suy ra phải đủ 30 QC từ việc có 30 job nguồn. Trạng thái done cho biết hoàn thành vòng thao tác, chưa chứng nhận mọi cuboid đúng. Báo cáo không thay thao tác Save/nộp trên hệ thống. Bằng chứng Robotaxi chỉ giữ/nộp theo quyền dữ liệu và kênh riêng được cấp.

## 6. Tổng kết cá nhân

- Công việc em trực tiếp thực hiện: [điền]
- Một kết quả A/B có dẫn file: [điền]
- Một kết quả B/C có dẫn file: [điền]
- Cách em giải thích chuyển z thuận/ngược: [điền bằng lời của mình]
- Quyết định khi cả batch lệch và khi một hộp lệch: [điền]
- Khó khăn, xử lý thực tế và phần chưa hoàn thành: [điền]
- Điều chưa chắc và bước kiểm tiếp theo: [điền]

Kết luận cần khớp kết quả thật, ví dụ: “Trong phạm vi một PCD và checkpoint đã dùng, thay đổi [biến] dẫn tới [quan sát có bằng chứng]. Em chưa kết luận cấu hình nào chính xác hơn do thiếu reference. Thí nghiệm ca QC giúp em phân biệt [bài học thực tế].”

## Tài liệu và phụ lục

Tài liệu nội bộ đã dùng: README.md, PRE-LABEL.md, PRE-LABEL-REPORT.md, RUBRIC.md, LABEL_GUIDELINE.md, HUONG-DAN.md, bundle/README-STUDENT.md, data/ATTRIBUTION.md và mã nguồn liên quan.

Trích dẫn dữ liệu: Andreas Geiger, Philip Lenz, Raquel Urtasun. *Are we ready for Autonomous Driving? The KITTI Vision Benchmark Suite.* CVPR, 2012; mẫu MMDetection3D 000008 và bản chuyển đổi theo provenance trong repo.

Phụ lục nên có: cấu hình/môi trường; smoke.json; ba CSV; JSON/ảnh Side A/B/C; manifest và JSON/ảnh ba ca QC; log lỗi nếu có. Bản viết và output đặt ngoài gói có manifest. Không dùng số liệu trong bundle/VALIDATION.md làm kết quả tự chạy; nếu được giao phân tích kết quả có sẵn, dẫn rõ nguồn và ghi chưa tự chạy.
