-- ============================================================
-- 传感器原始报文 LIKE 筛查 SQL（配合 demo_sensors.db 的 sensor_raw 表）
-- 背景：边缘网关长文本报文里，工程师常用 LIKE 按标记/设备/批次筛查。
-- 全部均为合法只读 SELECT/WITH，可直接在排查页执行。
-- 注意：对长文本做全量 LIKE 匹配可能超过 3 秒而被自动终止，
--      也可在运行中手动取消 —— 终止会真正中断计算并立即释放查询名额。
-- ============================================================

-- 1) 筛查重试批次报文（重试报文带 "flag":"RETRY" 标记）
SELECT id, sensor_id, ts, substr(raw_text, 1, 120) AS raw_head
FROM sensor_raw
WHERE raw_text LIKE '%"flag":"RETRY"%'
ORDER BY id
LIMIT 20;

-- 2) 按设备前缀 + 批次联合筛查
SELECT sensor_id, COUNT(*) AS n
FROM sensor_raw
WHERE raw_text LIKE '%"dev":"S-1001"%'
  AND raw_text LIKE '%"batch":"B-20261110-A"%'
GROUP BY sensor_id;

-- 3) WITH 子查询 + LIKE：统计含 RETRY 标记的报文占比
WITH retry AS (
  SELECT id FROM sensor_raw WHERE raw_text LIKE '%RETRY%'
)
SELECT (SELECT COUNT(*) FROM retry) AS retry_packets,
       (SELECT COUNT(*) FROM sensor_raw) AS total_packets;

-- 4) 未命中模式返回空结果（合法 LIKE，不应报错）
SELECT id, sensor_id FROM sensor_raw
WHERE raw_text LIKE '%NO-SUCH-MARKER-12345%'
LIMIT 10;

-- 5) 慢 LIKE（动态模式对长文本全量匹配，演示库上约 3.4s）：
--    用于演示超过 3 秒自动终止，或在页面上手动取消；
--    终止返回 timeout/cancelled 时计算已停、名额已还，可立即发起新查询。
SELECT COUNT(*) AS n
FROM (SELECT id FROM sensor_raw LIMIT 300) b, sensor_raw a
WHERE a.raw_text LIKE '%NOPE-' || b.id || '-ZZZ%';
