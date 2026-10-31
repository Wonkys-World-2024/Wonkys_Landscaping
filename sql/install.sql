CREATE TABLE IF NOT EXISTS `wonkys_landscaping_cells` (
 `plot_id` VARCHAR(64) NOT NULL,
 `cell_id` INT UNSIGNED NOT NULL,
 `cut_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
 PRIMARY KEY (`plot_id`, `cell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `wonkys_landscaping_employees` (
 `citizenid` VARCHAR(64) NOT NULL PRIMARY KEY,
 `employee_name` VARCHAR(100) NOT NULL,
 `jobs_completed` INT UNSIGNED NOT NULL DEFAULT 0,
 `total_xp` INT UNSIGNED NOT NULL DEFAULT 0,
 `lifetime_earnings` BIGINT UNSIGNED NOT NULL DEFAULT 0,
 `weekly_jobs` INT UNSIGNED NOT NULL DEFAULT 0,
 `weekly_xp` INT UNSIGNED NOT NULL DEFAULT 0,
 `last_completed` DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
