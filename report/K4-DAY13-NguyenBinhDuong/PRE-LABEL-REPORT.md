# Báo cáo cá nhân — Day 13: LiDAR 3D Object và PointPillars



## 1. Thông tin và mục tiêu

- Họ tên: Nguyễn Bình Dương
- MSSV/lớp: 2A202602170/lab304
- Ngày thực hiện: 02/10/2026.
- Hình thức: Cá nhân; thí nghiệm, kiểm tra output và soạn báo cáo có hỗ trợ Codex theo mô tả ở mục 6.
- Phạm vi thực tế: thí nghiệm A/B/C và ba ca QC trên KITTI; chưa thực hiện phần CVAT/portal.
- Trạng thái thực hiện: Đã chạy trên máy cá nhân bằng script với hỗ trợ Codex, Docker Desktop Linux amd64; A/B/C và helper QC đã hoàn tất, smoke.json passed.

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
| Hệ điều hành, CPU, RAM máy | Windows AMD64; Docker engine có 8 CPU và 3,754 GiB RAM; cấu hình RAM máy vật lý chưa ghi nhận |
| Architecture Docker | Image và Docker runtime: Linux amd64 (native) |
| Phiên bản Python và Docker | Python host 3.14 (lượt chạy Docker); Docker 29.7.2; môi trường inference theo image được cấp |
| Gói Student / tên ZIP | student-prelabel-amd64.zip; 12 file đã khớp hash/size manifest |
| Image tag và image ID | `day13-pointpillars:lc-20261001-amd64`; `sha256:e03983bd922ec29890bf547db8de408402efd82583680b62e671c20da2fd2c82` |
| Repo revision, working_tree_dirty | `0831856d921609312d42c7582c366e5a311bb7b1`; `True` (metadata của gói) |
| Checkpoint path và SHA256 | `/opt/PointPillars/pretrained/epoch_160.pth`; `482dfcf63b932cc5ccf012b4bbdad52aa51aa33becf87d0a39d61c39b377b5b1` |
| Input/frame và hash | `demo`; `3b5ea3da13e2b19149cab6a8d521c2ca55f2df93f026b5a3f8c273ce70645d60` |
| Thời điểm, trạng thái chạy | A/B/C và QC passed; thời gian từng bước ghi trong ket-qua-01/smoke.json |

Runner giới hạn mỗi container ở 4 CPU và 4 GB RAM, chạy tuần tự và tắt mạng khi inference. Đây là giới hạn cấp cho container, không phải số RAM thực đo hoặc RAM tối thiểu của máy.



### Thời gian lần chạy

Từ 19:48:09 đến 20:00:47 ngày 02/10/2026, giờ Việt Nam (UTC+7).

| Bước | Thời gian wall (giây) | Trạng thái |
| --- | ---: | --- |
| docker-load | 481.22 | passed |
| run-A | 54.01 | passed |
| run-B | 170.91 | passed |
| run-C | 39.11 | passed |
| qc-cases | 9.92 | passed |

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

> Số liệu dưới đây lấy từ lần chạy cá nhân ket-qua-01; đã đối chiếu số hộp CSV/JSON và kiểm biến đổi của ba ca QC.

### 4.1 Ba lượt inference

| Lượt | n_boxes từ CSV | mean_z từ CSV (m) | vehicles | pedestrian | two-wheels | File/vùng quan sát |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| A | 1 | 0.330 | 1 | 0 | 0 | `boxes-demo-delta-0-voxel-0.16.json`, `run-A/summary.csv` |
| B | 13 | 1.034 | 10 | 2 | 1 | `boxes-demo-delta-1.73-voxel-0.16.json`, `run-B/summary.csv` |
| C | 6 | 1.091 | 0 | 6 | 0 | `boxes-demo-delta-1.73-voxel-0.32.json`, `run-C/summary.csv` |

**A/B:** A có 1 hộp, B có 13 hộp; mean_z lần lượt là 0.330 m và 1.034 m. Đây là số liệu từ run-A/summary.csv và run-B/summary.csv, cùng frame/checkpoint/pillar nhưng khác delta. Cơ cấu class được đối chiếu trong bảng từ boxes JSON. Thay delta trước inference làm thay đổi prediction, không phải chỉ dịch lại bộ hộp cũ. Chưa có ground truth để kết luận B chính xác hơn.

**B/C:** B có 13 hộp, C có 6 hộp; mean_z lần lượt là 1.034 m và 1.091 m. Nguồn: run-B/summary.csv và run-C/summary.csv. Giữ delta/checkpoint/ROI và đổi cạnh pillar từ 0,16 lên 0,32 m làm prediction thay đổi như bảng thống kê class. Không thể suy ra chất lượng tốt hơn từ số hộp; C không được train lại cho pillar mới.

**Quan sát hình học đã đối chiếu ảnh:** Ảnh A chỉ có một hộp đỏ gần x≈13 m, phần đáy hình chữ nhật nằm dưới đường tham chiếu z=0. Ảnh B có các hộp đỏ trải từ vùng x≈4 m đến x≈56 m. JSON B xác nhận một vehicles tại tâm (55,580; -20,294; 1,222) m, trong khi ảnh A không có hộp tại vùng x này. Đây là khác biệt output, chưa chứng minh đối tượng được dự đoán đúng.

Trong ảnh C, không còn các hộp đỏ vehicles; sáu hộp màu cam pedestrian xuất hiện, chủ yếu ở x≈9–20 m và một hộp gần x≈34 m. Vùng x≈41 m và x≈56 m có hộp vehicles ở B nhưng không có hộp ở C. Vì Side bỏ trục y và vẽ length/height đơn giản, quan sát này chỉ hỗ trợ so sánh vị trí hiển thị, không xác nhận yaw hay accuracy.

**Quan sát ca QC:** Ảnh batch-z có các hộp dịch xuống đồng loạt, nhiều hộp nằm dưới đường z=0. Ảnh one-box-z chỉ có hộp gần x≈8,094 m dịch xuống, các hộp khác giữ vị trí như B. JSON xác nhận tâm z của hộp đầu B từ 0,921498 m xuống -0,883502 m, đúng lượng -1,805 m. Đường z=0 chỉ là tham chiếu; kết luận về phép dịch dựa trên đối chiếu JSON và biến đổi có kiểm soát.

mean_z chỉ là trung bình cao độ tâm các hộp được dự đoán; hai lượt có thể dự đoán các đối tượng khác nhau. Nhiều hộp hơn, score cao hơn hoặc mean_z thấp hơn không tự chứng minh tốt hơn.

### 4.2 Các ca QC có kiểm soát

Lấy N từ số hộp B và H từ `height_offset_m` trong `qc-cases/manifest.json`, với H = z_ground + delta. Helper sao chép B rồi thay đổi có chủ đích; tên `case-correct` chỉ là bản giữ nguyên chuyển đổi nguồn, không phải nhãn đúng.

| Ca | Số hộp bị thay đổi z so với B | Thay đổi z | Những trường còn giữ | Quyết định |
| --- | --- | --- | --- | --- |
| case-correct | 0/N | 0 | Toàn bộ nội dung boxes | Tiếp tục kiểm hình học; chưa chứng nhận prediction đúng |
| case-batch-z | N/N | -H m | class, x/y, kích thước, yaw, score | Dừng chỉnh tay cả batch, kiểm transform/pipeline và yêu cầu prediction được tạo lại đúng |
| case-one-box-z | 1/N | -H m ở hộp đầu tiên | Các hộp khác và trường ngoài z | Kiểm đối tượng qua nhiều view; không kết luận lỗi pipeline chỉ từ một hộp |

- N thực tế: 13 hộp.
- z_ground = 0.075 m; delta = 1.73 m; H = 1.805 m.
- Bằng chứng: qc-cases/case-correct.json, case-batch-z.json, case-one-box-z.json và manifest.json; ảnh side-correct.png, side-batch-z.png, side-one-box-z.png.
- Đối chiếu JSON thực tế: correct đổi 0/13 hộp; batch-z đổi 13/13 hộp; one-box-z đổi 1/13 hộp. Các trường ngoài z trong boxes giữ nguyên. Mỗi hộp bị đổi z lệch -1.805 m so với B.
- Không import ca training_only hoặc prediction KITTI demo vào job Robotaxi.

### 4.3 Giới hạn

Thí nghiệm dùng một frame đã chuyển đổi và không có ground truth trong gói. Reflectance thật đã bị bỏ; adapter dùng kênh hằng. Checkpoint và dữ liệu bài sửa Robotaxi có khác biệt miền dữ liệu. C thay pillar nhưng giữ checkpoint cũ. Ảnh Side của script là hình x-z đơn giản, bỏ thông tin y và vẽ hình chữ nhật theo length/height, không phải phép chiếu cuboid có xét yaw đầy đủ. Vì vậy không dùng riêng ảnh này để chốt yaw, ranh giới hoặc độ đúng từng hộp. Không tính accuracy/mAP/IoU khi chưa có nhãn reference và quy trình đánh giá phù hợp.

## 5. Phần CVAT/portal chưa thực hiện

Lần thực hiện này hoàn tất thí nghiệm KITTI và ca QC của gói Student. Chưa thao tác job Robotaxi, nộp v1, review bài khác hoặc phản hồi v2 trên CVAT/portal. Không ghi nhận các bước đó là đã hoàn thành. Nếu phiên bản bài cá nhân yêu cầu phần này, cần tài khoản/job được cấp và bổ sung bằng chứng thực tế.

## 6. Tổng kết và nhận xét cá nhân

Trong một PCD KITTI đã chuyển đổi, thay delta từ 0 lên 1,73 m khi giữ pillar 0,16 m làm số hộp tăng từ 1 lên 13. Giữ delta 1,73 m và tăng cạnh pillar lên 0,32 m làm số hộp giảm xuống 6, đồng thời class output chỉ còn pedestrian. Kết quả chứng minh prediction nhạy với cấu hình đầu vào trong lần chạy này, chưa xác định cấu hình nào chính xác hơn do thiếu reference.

Ba ca QC cho thấy dấu hiệu lệch đồng loạt cần kiểm phép chuyển tọa độ trước khi sửa tay; lệch một hộp cần kiểm đối tượng riêng. Phép chuyển thuận trừ z_ground và delta, phép ngược cộng lại chúng; với KITTI, script còn xử lý bottom-z/center-z. JSON xuất đã ở hệ nguồn.

Khó khăn thực tế: Docker được cài ở thư mục tài khoản nên chưa có trong PATH của phiên terminal. Script đã được cập nhật nhận đường dẫn này. Nạp image lần đầu mất khoảng 8 phút; sau đó A/B/C và helper đều chạy thành công. PyTorch có cảnh báo meshgrid về API tương lai, không làm lần chạy thất bại. Thời gian đo gồm khởi động container và chịu ảnh hưởng tải máy; không coi đây là benchmark tốc độ model thuần.

- Người thực hiện: Nguyễn Bình Dương — 2A202602170/lab304.
- Vai trò và mức hỗ trợ: dữ liệu được cung cấp và Docker được mở trên máy cá nhân; Codex hỗ trợ kiểm tra gói, thực hiện lệnh chạy, đối chiếu output và soạn báo cáo từ kết quả thực tế.
- Phần chưa thực hiện: CVAT/portal nếu được giao.

### Nhận xét về ảnh hưởng của delta

Từ kết quả A/B, em nhận thấy phép chuyển tọa độ trước inference có ảnh hưởng đáng kể đến dự đoán. Với cùng pillar 0,16 m, A chỉ có 1 hộp vehicles, còn B có 13 hộp thuộc ba class. Trong ảnh Side, A chỉ có hộp gần x≈13 m, trong khi B có các hộp phân bố ở nhiều vị trí, bao gồm vùng x≈41 m và x≈56 m. Sự thay đổi này cho thấy đổi delta không đơn thuần làm hộp cũ dịch lên hoặc xuống; model xử lý lại input đã chuyển tọa độ và có thể tạo tập prediction khác. Tuy nhiên, em chưa thể khẳng định B chính xác hơn vì chưa có ground truth để xác nhận các hộp đó.

### Nhận xét về kích thước pillar

Khi giữ delta 1,73 m và tăng cạnh pillar từ 0,16 m lên 0,32 m, số hộp giảm từ 13 xuống 6; output C chỉ còn pedestrian, không có vehicles hoặc two-wheels. Điều có thể kết luận từ lần chạy này là cấu hình pillar ảnh hưởng đến số lượng và cơ cấu class của prediction. Pillar lớn hơn làm cách gom điểm trên mặt phẳng x-y thay đổi và giảm độ phân giải lưới; đây là một hướng giải thích cho khác biệt quan sát được, chưa phải bằng chứng xác định nguyên nhân của từng hộp. Vì C dùng lại checkpoint chưa được train riêng cho pillar mới, em không xem kết quả này là kết luận chung rằng pillar nhỏ luôn tốt hơn pillar lớn.

### Nhận xét về cách đánh giá kết quả

Em không chọn cấu hình tốt nhất chỉ dựa trên số hộp hoặc mean_z. Nhiều hộp hơn có thể gồm cả hộp thừa; ít hộp hơn có thể do bỏ sót hoặc do loại được dự đoán sai. mean_z của A, B và C lần lượt là 0,330 m, 1,034 m và 1,091 m, nhưng các tập hộp khác nhau nên không thể xem đây là mức cải thiện chất lượng. Cần đối chiếu từng đối tượng với point cloud, nhiều góc nhìn và reference được duyệt. Ảnh Side hữu ích để nhận dấu hiệu lệch chiều cao, nhưng bỏ thông tin y và không thể hiện đầy đủ yaw, nên không đủ để xác nhận hình học 3D.

### Nhận xét về QC pipeline và từng đối tượng

Ca batch-z làm toàn bộ 13 hộp lệch xuống 1,805 m, đúng bằng z_ground + delta = 0,075 + 1,73 m. Nếu gặp dấu hiệu tương tự trên dữ liệu thực tế, em sẽ dừng sửa từng hộp và kiểm tra hệ tọa độ, phép chuyển thuận/ngược cùng quy ước bottom-z/center-z trước. Ca one-box-z chỉ làm hộp đầu tiên gần x≈8,094 m đổi tâm z từ 0,921498 m thành -0,883502 m; các hộp khác giữ nguyên. Trường hợp đó cần kiểm đối tượng riêng qua nhiều view, không đủ để kết luận toàn pipeline lỗi. Tên case-correct chỉ biểu thị bản giữ nguyên prediction B, không bảo đảm các hộp của B là nhãn đúng.

### Bài học và điều chưa chắc

Bài học rút ra từ thí nghiệm là cần kiểm tính nhất quán của dữ liệu, cấu hình và phép chuyển tọa độ trước khi đánh giá hoặc chỉnh pre-label. Khi viết nhận xét, cần tách số liệu quan sát được khỏi giả thuyết giải thích và dẫn file hoặc vùng cụ thể. Giới hạn còn lại là chỉ có một frame KITTI đã chuyển đổi, reflectance thật bị bỏ và không có ground truth hay ảnh camera trong gói. Vì vậy, chưa xác định được hộp nào đúng, hộp nào thừa hoặc cấu hình nào có accuracy cao hơn. Bước kiểm tiếp theo phù hợp là dùng dữ liệu/reference được cấp để đối chiếu từng hộp; phần Robotaxi trên CVAT/portal chỉ được bổ sung sau khi thực hiện thực tế.

## Tài liệu và phụ lục

Tài liệu nội bộ đã dùng: README.md, PRE-LABEL.md, PRE-LABEL-REPORT.md, RUBRIC.md, LABEL_GUIDELINE.md, HUONG-DAN.md, bundle/README-STUDENT.md, data/ATTRIBUTION.md và mã nguồn liên quan.

Trích dẫn dữ liệu: Andreas Geiger, Philip Lenz, Raquel Urtasun. *Are we ready for Autonomous Driving? The KITTI Vision Benchmark Suite.* CVPR, 2012; mẫu MMDetection3D 000008 và bản chuyển đổi theo provenance trong repo.

Phụ lục nên có: cấu hình/môi trường; smoke.json; ba CSV; JSON/ảnh Side A/B/C; manifest và JSON/ảnh ba ca QC; log lỗi nếu có. Bản viết và output đặt ngoài gói có manifest. Không dùng số liệu trong bundle/VALIDATION.md làm kết quả tự chạy; nếu được giao phân tích kết quả có sẵn, dẫn rõ nguồn và ghi chưa tự chạy.

### Bằng chứng và cách tái tạo

Số liệu trong báo cáo lấy từ lần chạy thực tế ngày 02/10/2026, smoke.json passed. Output gốc được giữ trên máy và không đính kèm repo này. Các tên JSON/PNG/CSV trong báo cáo là tên bằng chứng local, không phải liên kết tải từ GitHub. Chạy lại bằng gói Student amd64 và script CHAY-THI-NGHIEM-CA-NHAN.ps1 ở repo root; đối chiếu output với bảng kết quả. Không yêu cầu prediction khớp bitwise giữa máy. Repo bài nộp chỉ chứa hai file Markdown trong thư mục report/K4-DAY13-NguyenBinhDuong; chưa có dữ liệu hoặc bài làm Robotaxi.
