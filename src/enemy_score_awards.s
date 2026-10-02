; Награды за уничтожение типов противников ($E8BA-$E8BD).

; Четыре packed-decimal награды runtime collision path, индекс enemy type 0..3:
; high nibble идёт в сотни, low — в десятки, поэтому значения дают 100, 200,
; 300 и 400 points. Bounds check у consumer-а нет: индекс вне 0..3 читает
; соседние ROM-данные. Отдельный дубликат ScoreAwardsByEnemyType используется
; экраном статистики для отложенного подсчёта; ромхак обязан менять обе таблицы
; синхронно, иначе итоговый score и показанная статистика разойдутся. Packed
; digits должны быть 0..9, а $00 означал бы special award 1000, не ноль.
EnemyTypeScoreAwards:
LE8BA:  .byte   $10,$20,$30,$40
