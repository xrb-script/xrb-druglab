CREATE TABLE IF NOT EXISTS `drug_labs` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `type` VARCHAR(50) NOT NULL,
  `price` INT NOT NULL,
  `owner_identifier` VARCHAR(100) DEFAULT NULL,
  `owner_name` VARCHAR(100) DEFAULT NULL,
  `stock_raw` INT DEFAULT 0,
  `stock_packaged` INT DEFAULT 0,
  `pos_x` FLOAT NOT NULL,
  `pos_y` FLOAT NOT NULL,
  `pos_z` FLOAT NOT NULL,
  `stash_pos_x` FLOAT NOT NULL,
  `stash_pos_y` FLOAT NOT NULL,
  `stash_pos_z` FLOAT NOT NULL,
  `process_pos_x` FLOAT NOT NULL,
  `process_pos_y` FLOAT NOT NULL,
  `process_pos_z` FLOAT NOT NULL,
  `keys` TEXT DEFAULT '[]'
);