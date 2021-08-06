-- compatible with acore-cms and mycred plugin
SELECT CONCAT(
    'UPDATE wp_usermeta SET meta_value = meta_value + ',
    `ac_eluna`.`eventscript_score`.`score_earned_current`,
    ' WHERE meta_key = "mycred_default" AND user_id =',
    account_id, ';') AS `query` FROM ac_eluna.eventscript_score;
    
-- run this ONLY if you already distributed the points
UPDATE ac_eluna.eventscript_score SET `score_earned_current` = 0;