# Phase 1 — phân tích và nhật ký

## Yêu cầu và acceptance criteria

Mục tiêu là một màn 3D chơi được với Mây, đảo tròn, năm đèn lớn, đom đóm có thể nhặt, Bóng Mực truy đuổi và gây mất lửa, xung sáng đẩy/làm choáng kẻ địch, chiến thắng khi thắp đủ đèn, thất bại khi hết lửa hoặc trời sáng, HUD/điểm và chơi lại. Headless phải mô phỏng 60 tick/giây, nhận scenario/inputs, phát JSONL chính xác về tick, trạng thái, event và kết thúc; cùng input/seed phải cho output giống nhau.

| ID | Yêu cầu | Triển khai | Kiểm chứng | Trạng thái |
|---|---|---|---|---|
| P1-01 | Game 3D, Mây, đảo tròn, camera và nhảy | `project.godot`, `scenes/game.tscn`, `src/game.gd` tạo scene 3D procedural; camera theo nhân vật; nhảy trong mô phỏng | Godot 4.7.2 compile scan và chạy scene headless ba frame; GUI playtest | Compile/headless PASS; GUI chưa xác minh |
| P1-02 | 5 đèn, 3 đom đóm/đèn | `src/simulation.gd`, interact trong phạm vi 2m | scenario đặt sẵn mote, tương tác nạp và thắp | Headless deposit/light PASS; GUI chưa xác minh |
| P1-03 | Mote rải trên đảo, có thể nhặt | setup seed tạo mote; bán kính 1.25m; tối đa 5 mang theo | fixture pickup, snapshot/event | Headless pickup PASS; GUI chưa xác minh |
| P1-04 | Bóng Mực đuổi và chạm gây mất lửa | tốc độ 2.2m/s, phạm vi chạm 1m, bất tử 1.5s | fixture hit | Headless hit PASS; hình ảnh truy đuổi chưa xác minh |
| P1-05 | Pulse tốn 1, đẩy 2.5m, choáng 2s | pulse radius 6m, cooldown 1s | fixture pulse | Headless stun PASS; push/GUI chưa xác minh |
| P1-06 | Thắng/thua, điểm, HUD, chơi lại | mô phỏng kết thúc và HUD scene | kịch bản thắng/thua và kiểm tra UI | Chưa xác minh end-to-end/GUI |
| P1-07 | Contract file và CLI headless | `game.contract.json`, `src/headless.gd` | `tests/run_contract.py` | PASS 6/6 trên Godot 4.7.2 |
| P1-08 | Tick, input edge, JSONL, determinism, validation | core mô phỏng cố định, parser scenario/input | smoke scenarios, deterministic comparison, lỗi schema | Các kiểm tra runner PASS; chưa xác minh mọi edge case |
| P1-09 | Ghi giả định, AI usage, evidence | file này và `docs/proof/phase-1/verification.md` | review tài liệu | Tài liệu và log runtime có; GUI screenshots chưa có |

## Functional / non-functional requirements

- Functional: đi/chạy, nhảy, thu thập, nạp vào đèn, truy đuổi, sát thương, hồi bất tử, pulse, spawn, thắng/thua, score/HUD/restart, scenario và input frames.
- Non-functional: Godot 4 / GDScript theo harness; logic tách renderer; deterministic khi seed/scenario/inputs giống nhau; headless không yêu cầu cửa sổ/GPU; output vị trí làm tròn 3 chữ số.
- Entities: player Mây (pos, carried, flames), mote (id/pos), lantern (id/pos/deposited/lit), shade (id/pos/state/stun). State game: `playing`, `won`, `lost`; state shade tối thiểu `chase`, `stunned`.
- Luồng mỗi tick: áp input frame → di chuyển/nhảy → edge actions → pickup → AI/va chạm → tăng sim tick/giảm đồng hồ → xét kết thúc → emit event/snapshot.

## Giả định đã chọn

- Lantern cost 3; capacity 5; Night 1 kéo dài 300s; bắt đầu 3 flames.
- Mote 10 điểm, thắp đèn 100, mỗi shade bị choáng 15, mỗi giây còn lại 1, mỗi flame còn lại khi thắng 25.
- Hit làm mất một flame, không làm rơi mote (`hit_drop_ratio=0`); bất tử 1.5s. Fall không có phạt. Đèn thắp xong tạo vùng an toàn 4m.
- Mote/shade mặc định sinh theo seed; scenario có cờ random false tắt spawn tương ứng. Mote mới mỗi 240 tick khi số lượng dưới 30; shade mới mỗi 900 tick.
- Chạm E chọn đèn chưa thắp gần nhất trong 2m và nạp lượng vừa đủ; hành động chỉ chạy ở cạnh false→true. Đom đóm nhặt tự động khi trong 1.25m.
- Jump có tốc độ đầu 7m/s và trọng lực 18m/s²; gameplay tương tác vẫn dùng XZ như contract.
- `team` dùng MSSV và tên Latin theo thư mục repo.

## Rủi ro còn lại

Godot 4.7.2 đã compile scan project, chạy scene headless ba frame và chạy 6/6 contract checks. Môi trường này không có X11/Wayland nên chưa playtest GUI, kiểm tra HUD, thắng/thua/replay bằng thao tác thật hoặc chụp screenshot. Độ khó cân bằng và bố cục màn chơi vẫn cần playtest.

## Nhật ký dùng AI

- Dùng Codex để đọc PRD, harness, xây core GDScript, headless runner, scene 3D, smoke fixtures và tài liệu.
- Ước tính token/chi phí: không có bộ đếm chi phí đáng tin trong phiên làm việc; số liệu không được bịa. Ghi nhận: một phiên Codex, không gọi dịch vụ AI ngoài.
- Tiết kiệm: giữ toàn bộ game trong vài module; dùng hình khối procedural thay asset; viết một runner scenario tái sử dụng.
- Điểm cần con người đánh giá: chạy Godot 4, kiểm tra cú pháp, chơi thử, điều chỉnh cảm giác điều khiển, chụp ảnh bằng chứng.
