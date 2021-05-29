-- phpMyAdmin SQL Dump
-- version 5.0.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: May 29, 2021 at 08:52 PM
-- Server version: 10.3.27-MariaDB-0+deb10u1
-- PHP Version: 7.3.27-1~deb10u1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `automataDB`
--
CREATE DATABASE IF NOT EXISTS `automataDB` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `automataDB`;

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`automata_admin`@`localhost` PROCEDURE `run_DFA` (IN `testString` VARCHAR(255), IN `testMachine` BINARY(64), OUT `result` BOOLEAN)  main:BEGIN
	DECLARE curState varchar(20);
	DECLARE transState varchar(20);
	DECLARE endType enum('REG','FIN','STA');
	DECLARE alpha char(1);
   	DECLARE len INT;
	DECLARE i INT;
	DECLARE rowCount INT;

	set len = length(testString);
	set rowCount = 0;
	set i = 1;

	SELECT stateID into curState from machines where stateType='STA' and machineID = testMachine limit 1;
	IF curState is NULL then
		signal sqlstate '45000' set message_text = 'Could not find a state to start with';
	END IF;

	main_loop:	LOOP
		SET alpha = SUBSTRING(testString,i,1);
		if alpha = '\0' then
			LEAVE main_loop;
		elseif alpha = '<' then
			signal sqlstate '45000' set message_text = 'DFAs cannot handle empty transitions';
		end if;

		SELECT toState into transState from machines where alphabet = alpha and stateID=curState and machineID = testMachine limit 1;	

		
		SELECT ROW_COUNT() into rowCount;
		if rowCount < 1 then
			set result = false;
			LEAVE main;
		end if;

		set curState = transState;

		
		SET i = i + 1;
		IF i <= len then
			ITERATE main_loop;
		ELSE
			LEAVE main_loop;
		END IF;
	END LOOP;

	SELECT stateType into endType from machines where stateID=curState and machineID = testMachine limit 1;
	if endType = 'FIN' then
		set result = true;
	else
		set result = false;
	end if;

END$$

CREATE DEFINER=`automata_admin`@`localhost` PROCEDURE `run_machine` (IN `testString` VARCHAR(255), IN `testMachine` BINARY(64), OUT `result` BOOLEAN)  BEGIN
	DECLARE rowCount INT;
	DECLARE mType enum('DFA','NFA');

		
	SELECT count(*) INTO rowCount from machines where machineID = testMachine;
	IF rowCount <= 0 then
		signal sqlstate '45000' set message_text = 'Machine not stored on the server';
	END IF;

	
	IF testString is NULL or LENGTH(testString) <= 0 then
		signal sqlstate '45000' set message_text = 'Cannot evaluate an empty string';
	END IF;

	
	SELECT machineType INTO mType from machine_metadata where machineID = testMachine;

	
	IF mType = 'DFA' then
		CALL run_DFA(testString, testMachine, result);
	ELSEIF mType = 'NFA' then
		CALL run_NFA(testString, testMachine, result);
	ELSE
		signal sqlstate '45000' set message_text = 'Machine not stored on the server';
	END IF;

END$$

CREATE DEFINER=`automata_admin`@`localhost` PROCEDURE `run_NFA` (IN `testString` VARCHAR(255), IN `testMachine` BINARY(64), OUT `result` BOOL)  main:BEGIN
    
    DECLARE string_len INT;
    DECLARE string_index INT;
    DECLARE alpha CHAR(1);
    DECLARE curState varchar(20);

    
    DECLARE states_len INT;
    DECLARE states_index INT;

    
    DECLARE trans_count INT;
    DECLARE trans_index INT;
    DECLARE trans_state varchar(20);
    DECLARE added INT;

    
    DECLARE endStateType enum('REG', 'FIN', 'STA');

    
    DECLARE currentArray BLOB;
    DECLARE tempStatesArray BLOB;

    
    SELECT stateID into curState from machines where stateType='STA' and machineID = testMachine limit 1;
	IF curState is NULL then
		signal sqlstate '45000' set message_text = 'Could not find a state to start with';
	END IF;
    SET currentArray = JSON_ARRAY(curState);

    
    SET string_len = LENGTH(testString);
    SET string_index = 1;
    string_loop:    LOOP
        
        SET alpha = SUBSTRING(testString,string_index,1);
        SET tempStatesArray = JSON_ARRAY();  

        
        SET states_len = JSON_LENGTH(currentArray);
        SET states_index = 0;
        states_loop: LOOP
            
            SET curState = JSON_EXTRACT(currentArray,CONCAT('$[',states_index,']'));
            SET curState = REPLACE(curState, '"','');

            

            
            SELECT count(toState) into trans_count from machines where 
                machineID = testMachine and alphabet = alpha and stateID = curState;

            
            SET trans_index = 0;
            trans_loop: LOOP
                
                SELECT toState INTO trans_state from machines where 
                    machineID = testMachine and (alphabet = alpha or alphabet = '<') and stateID = curState
                    LIMIT trans_index,1;

                
                IF trans_state is not NULL then
                    SELECT JSON_CONTAINS(tempStatesArray, CONCAT('"',trans_state,'"'), '$') into added;
                    IF added is NULL or added = 0 then
                        SET tempStatesArray = JSON_ARRAY_INSERT(tempStatesArray, '$[0]', trans_state);
                    END IF;
                END IF;

                
                SET trans_index = trans_index + 1;
                IF trans_index < trans_count then
                    ITERATE trans_loop;
                ELSE
                    LEAVE trans_loop;
                END IF;
            END LOOP;

            
            SET states_index = states_index + 1;
            IF states_index < states_len then
                ITERATE states_loop;
            ELSE
                LEAVE states_loop;
            END IF;
        END LOOP;

        
        IF JSON_LENGTH(tempStatesArray) <= 0 then
            SET result = false;
            LEAVE main;
        END IF;

        
        SET currentArray = tempStatesArray;
        
        
        SET string_index = string_index + 1;
        IF string_index <= string_len then 
            ITERATE string_loop;
        ELSE
            LEAVE string_loop;
        END IF;
    END LOOP;

    
    SET states_len = JSON_LENGTH(currentArray);
    SET states_index = 0;
    fin_loop:   LOOP
        SET curState = JSON_EXTRACT(currentArray,CONCAT('$[',states_index,']'));
        SET curState = REPLACE(curState, '"','');

        SELECT stateType into endStateType from machines where 
            machineID = testMachine and stateID = curState limit 1;

        IF endStateType = 'FIN' then
            SET result = true;
            LEAVE main;
        END IF;

        
        SET states_index = states_index + 1;
        IF states_index < states_len then
            ITERATE fin_loop;
        ELSE
            LEAVE fin_loop;
        END IF;
    END LOOP;
    
    SET result = false;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `machines`
--

CREATE TABLE `machines` (
  `machineID` binary(64) NOT NULL,
  `machineName` varchar(255) DEFAULT NULL,
  `stateID` varchar(20) DEFAULT NULL,
  `stateType` enum('REG','FIN','STA') NOT NULL DEFAULT 'REG',
  `alphabet` char(1) DEFAULT NULL,
  `toState` varchar(20) DEFAULT NULL,
  `rowID` tinyint(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Triggers `machines`
--
DELIMITER $$
CREATE TRIGGER `trigger_machineType` AFTER INSERT ON `machines` FOR EACH ROW BEGIN
	IF NEW.rowid = -1 then
		INSERT IGNORE INTO machine_metadata values(NEW.machineID, @machineType);
		SELECT row_count() into @rowcount;
		if @rowcount < 1 then
			UPDATE machine_metadata set machineType = @machineType where machineID = NEW.machineID;
		end if;

	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trigger_validateStart` BEFORE INSERT ON `machines` FOR EACH ROW BEGIN
	IF NEW.rowid = 1 or NEW.rowid = -2 then
		set @startCount = 0;
		set @finalCount = 0;    
		set @lastRowID = NULL;
		set @machineType = 'DFA';
		set @startStateID = NULL;
		set @machineID = NEW.machineID;
		set @rowcount = 0;		
	
		DROP TEMPORARY TABLE IF EXISTS alphabets;
		CREATE TEMPORARY TABLE alphabets (alps char(1) not null,state varchar(20) not null,primary key (alps,state));

		
		
		SELECT count(*) into @isExists from machines where machineID = NEW.machineID;
		IF @isExists > 0 then
			signal sqlstate '45000' set message_text='This machine already exists';
		END IF;
	END IF;


	IF NEW.stateType = 'STA' then
		
		IF NEW.stateID != @startStateID or @startStateID is null then
			set @startCount = @startCount + 1;
			set @startStateID = NEW.stateID;
		END IF;

		IF @startCount > 1 then
			signal sqlstate '45000' set message_text = 'Multiple start states';
		END IF;

	
	ELSEIF NEW.stateType = 'FIN' then
		set @finalCount = @finalCount + 1;
	END IF;

	
	IF @machineType = 'DFA' then
		
		IF NEW.alphabet = '<' then
			set @machineType = 'NFA';
		END IF;

		
		INSERT IGNORE into alphabets values(NEW.alphabet,NEW.stateID);
		SELECT ROW_COUNT() INTO @rowcount;	
		IF @rowcount < 1 then
			set @machineType = 'NFA';
		END IF;
	END IF;	

	
	IF NEW.rowid = -1 or NEW.rowid = -2 then
		IF @startCount < 1 then
			signal sqlstate '45000' set message_text = 'No start state';
		ELSEIF @finalCount < 1 then
			signal sqlstate '45000' set message_text = 'No final state';
		END IF;
	END IF;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `machine_metadata`
--

CREATE TABLE `machine_metadata` (
  `machineID` binary(64) NOT NULL,
  `machineType` enum('NFA','DFA') NOT NULL DEFAULT 'DFA'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Triggers `machine_metadata`
--
DELIMITER $$
CREATE TRIGGER `trigger_deleteMetadata` AFTER DELETE ON `machine_metadata` FOR EACH ROW BEGIN
	DELETE IGNORE FROM machines where machineID = OLD.machineID;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `view_fullMachine`
-- (See below for the actual view)
--
CREATE TABLE `view_fullMachine` (
`Machine ID` varchar(128)
,`Name` varchar(255)
,`Machine Type` enum('NFA','DFA')
,`State` varchar(20)
,`Type` enum('REG','FIN','STA')
,`Transition alphabet` char(1)
,`To State` varchar(20)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `view_machine`
-- (See below for the actual view)
--
CREATE TABLE `view_machine` (
`Name` varchar(255)
,`Machine Type` enum('NFA','DFA')
,`State` varchar(20)
,`Type` enum('REG','FIN','STA')
,`Transition alphabet` char(1)
,`To State` varchar(20)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `view_transitions`
-- (See below for the actual view)
--
CREATE TABLE `view_transitions` (
`Name` varchar(255)
,`State` varchar(20)
,`Type` enum('REG','FIN','STA')
,`Transition Alphabet` char(1)
,`To State` varchar(20)
);

-- --------------------------------------------------------

--
-- Structure for view `view_fullMachine`
--
DROP TABLE IF EXISTS `view_fullMachine`;

CREATE ALGORITHM=UNDEFINED DEFINER=`automata_admin`@`localhost` SQL SECURITY DEFINER VIEW `view_fullMachine`  AS  select hex(`machines`.`machineID`) AS `Machine ID`,`machines`.`machineName` AS `Name`,`machine_metadata`.`machineType` AS `Machine Type`,`machines`.`stateID` AS `State`,`machines`.`stateType` AS `Type`,`machines`.`alphabet` AS `Transition alphabet`,`machines`.`toState` AS `To State` from (`machines` left join `machine_metadata` on(`machine_metadata`.`machineID` = `machines`.`machineID`)) ;

-- --------------------------------------------------------

--
-- Structure for view `view_machine`
--
DROP TABLE IF EXISTS `view_machine`;

CREATE ALGORITHM=UNDEFINED DEFINER=`automata_admin`@`localhost` SQL SECURITY DEFINER VIEW `view_machine`  AS  select `machines`.`machineName` AS `Name`,`machine_metadata`.`machineType` AS `Machine Type`,`machines`.`stateID` AS `State`,`machines`.`stateType` AS `Type`,`machines`.`alphabet` AS `Transition alphabet`,`machines`.`toState` AS `To State` from (`machines` left join `machine_metadata` on(`machine_metadata`.`machineID` = `machines`.`machineID`)) ;

-- --------------------------------------------------------

--
-- Structure for view `view_transitions`
--
DROP TABLE IF EXISTS `view_transitions`;

CREATE ALGORITHM=UNDEFINED DEFINER=`automata_admin`@`localhost` SQL SECURITY DEFINER VIEW `view_transitions`  AS  select `machines`.`machineName` AS `Name`,`machines`.`stateID` AS `State`,`machines`.`stateType` AS `Type`,`machines`.`alphabet` AS `Transition Alphabet`,`machines`.`toState` AS `To State` from (`machines` left join `machine_metadata` on(`machine_metadata`.`machineID` = `machines`.`machineID`)) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `machine_metadata`
--
ALTER TABLE `machine_metadata`
  ADD PRIMARY KEY (`machineID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
