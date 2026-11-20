# Đảo Đèn Lồng — Phase 1

Game 3D góc nhìn thứ ba xây bằng Godot 4 và GDScript. Phase này có một đảo tròn, năm đèn, đom đóm, Bóng Mực, nhảy, tỏa sáng, HUD và màn kết thúc.

## Cài đặt và chạy

Tải Godot 4.2 trở lên cho hệ điều hành của bạn từ [trang tải chính thức](https://godotengine.org/download/). Sau đó từ thư mục repo chạy:

```sh
godot --headless --editor --path . --quit
godot --path .
```

Trên máy dùng executable tên `godot4`, thay `godot` bằng `godot4`. Không cần asset ngoài hoặc GPU cho headless.

## Điều khiển

- `WASD` hoặc phím mũi tên: di chuyển.
- `Space`: nhảy.
- `E`: nạp đom đóm vào đèn đang gần nhất.
- `Q`: tỏa sáng, tiêu hao 1 đom đóm và làm choáng Bóng Mực trong bán kính.
- `R`: chơi lại sau khi thắng hoặc thua.

Mây mang tối đa 5 đom đóm. Mỗi đèn cần 3; chạm đèn nhiều lần nếu cần. Điểm: 10 mỗi đom đóm nhặt, 100 mỗi đèn thắp, 15 mỗi Bóng Mực bị choáng, cộng số giây còn lại và 25 điểm mỗi ngọn lửa khi thắng.

## Chạy kiểm tra headless

```sh
godot --headless --path . --script res://src/headless.gd -- --seed 42 --night 1 --ticks 600 --out /tmp/dao-den-long.jsonl
python3 tests/run_contract.py
```

Các tùy chọn đầy đủ nằm trong `phase1.txt` (Test Contract v1.0) và `game.contract.json`. Lệnh chuẩn để harness nối tham số là `godot --headless --path . --script res://src/headless.gd --`. Đầu ra JSONL có snapshot tick 0, event theo tick, snapshot định kỳ và dòng `end`. Dùng `--scenario file.json` và `--inputs file.json` để dựng các ca kiểm thử. File sai định dạng trả mã 2; lỗi ghi file hoặc lỗi chạy trả mã khác 0.

## Sáng tạo của tôi

Đảo có viền mây, ánh trăng tím, đom đóm phát sáng, Mây đội nón lá và đèn lớn chuyển sang ánh vàng khi thắp. Đây là lớp trình bày; logic dùng chung với headless. Smoke scenarios kiểm tra nhặt, nạp/thắp đèn, pulse và bị chạm. Tính tất định được kiểm tra bằng cách so sánh byte đầu ra của hai lần chạy cùng seed/fixture.

## Giả định và giới hạn Phase 1

Xem [docs/notes/phase-1.md](docs/notes/phase-1.md) để biết con số tuning, cách tính điểm và các giả định đã chọn. Rơi khỏi đảo không gây phạt (`fall_enabled: false`). Nhảy chỉ đổi tọa độ Y; tương tác đo khoảng cách ngang XZ theo contract. Đêm dài 300 giây; Bóng Mực mới xuất hiện theo chu kỳ trong gameplay mặc định, nhưng không tự xuất hiện trong scenario có `random_shades: false`.

## Bằng chứng

Fixtures, script kiểm tra và output test headless 6/6 nằm trong `tests/` và `docs/proof/phase-1/`. Godot 4.7.2 đã chạy compile scan và scene headless; GUI chưa xác minh vì môi trường không có X11/Wayland. Xem [verification report](docs/proof/phase-1/verification.md) để biết trạng thái từng hạng mục.
