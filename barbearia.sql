-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: barbearia_db
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `agendamentos`
--

DROP TABLE IF EXISTS `agendamentos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `agendamentos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `cliente_id` int unsigned NOT NULL,
  `colaborador_id` int unsigned NOT NULL,
  `servico_id` int unsigned NOT NULL,
  `data_hora` datetime NOT NULL,
  `duracao_min` smallint NOT NULL,
  `status` enum('pendente','confirmado','concluido','cancelado') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'confirmado',
  `valor_cobrado` decimal(8,2) NOT NULL,
  `observacao` text COLLATE utf8mb4_unicode_ci,
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atualizado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_agend_servico` (`servico_id`),
  KEY `idx_colaborador_data` (`colaborador_id`,`data_hora`),
  KEY `idx_cliente_data` (`cliente_id`,`data_hora`),
  KEY `idx_status` (`status`),
  KEY `idx_data_hora` (`data_hora`),
  CONSTRAINT `fk_agend_cliente` FOREIGN KEY (`cliente_id`) REFERENCES `usuarios` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_agend_colaborador` FOREIGN KEY (`colaborador_id`) REFERENCES `colaboradores` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_agend_servico` FOREIGN KEY (`servico_id`) REFERENCES `servicos` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `agendamentos`
--

LOCK TABLES `agendamentos` WRITE;
/*!40000 ALTER TABLE `agendamentos` DISABLE KEYS */;
INSERT INTO `agendamentos` VALUES (1,15,1,12,'2026-06-20 10:00:00',20,'cancelado',25.00,NULL,'2026-06-11 10:14:45','2026-06-11 15:50:12'),(2,15,1,12,'2026-06-18 13:40:00',20,'cancelado',25.00,NULL,'2026-06-11 10:22:16','2026-06-11 15:50:10'),(3,15,1,12,'2026-06-11 14:00:00',20,'concluido',25.00,NULL,'2026-06-11 10:25:04','2026-06-11 15:42:00'),(4,15,3,12,'2026-06-13 15:00:00',20,'concluido',25.00,NULL,'2026-06-12 00:02:17','2026-06-12 00:09:06'),(5,15,3,11,'2026-06-17 19:30:00',50,'concluido',55.00,NULL,'2026-06-12 00:05:03','2026-06-12 00:09:08'),(6,15,3,14,'2026-06-17 16:45:00',15,'concluido',25.00,NULL,'2026-06-12 00:05:18','2026-06-12 00:09:07'),(7,15,3,14,'2026-06-17 17:00:00',15,'concluido',25.00,NULL,'2026-06-12 00:05:40','2026-06-12 00:09:07'),(8,15,3,11,'2026-06-12 19:30:00',50,'concluido',55.00,NULL,'2026-06-12 00:12:35','2026-06-12 00:13:05'),(9,15,3,12,'2026-06-13 12:30:00',85,'confirmado',105.00,NULL,'2026-06-12 17:51:35','2026-06-12 17:51:35'),(10,15,3,12,'2026-06-16 17:00:00',115,'confirmado',140.00,NULL,'2026-06-12 17:57:31','2026-06-12 17:57:31'),(11,15,3,11,'2026-06-24 14:00:00',65,'confirmado',110.00,NULL,'2026-06-13 02:43:41','2026-06-13 02:43:41'),(12,15,3,14,'2026-06-24 15:30:00',15,'confirmado',25.00,NULL,'2026-06-13 02:43:57','2026-06-13 02:43:57'),(13,18,3,14,'2026-06-17 15:30:00',15,'confirmado',25.00,NULL,'2026-06-13 02:44:49','2026-06-13 02:44:49');
/*!40000 ALTER TABLE `agendamentos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `barbearias`
--

DROP TABLE IF EXISTS `barbearias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `barbearias` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int unsigned NOT NULL,
  `nome` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descricao` text COLLATE utf8mb4_unicode_ci,
  `logo_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cor_primaria` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT '#1A1A1A',
  `cor_secundaria` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT '#C9A84C',
  `telefone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `endereco` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ativa` tinyint(1) NOT NULL DEFAULT '1',
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atualizado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_id` (`admin_id`),
  CONSTRAINT `fk_barbearia_admin` FOREIGN KEY (`admin_id`) REFERENCES `usuarios` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `barbearias`
--

LOCK TABLES `barbearias` WRITE;
/*!40000 ALTER TABLE `barbearias` DISABLE KEYS */;
INSERT INTO `barbearias` VALUES (1,1,'Barbearia Teste','Barbearia de bairro','/uploads/logo_1781142189436.png','#2980B9','#1A1A1A',NULL,NULL,1,'2026-06-01 20:28:58','2026-06-13 02:45:56');
/*!40000 ALTER TABLE `barbearias` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `colaboradores`
--

DROP TABLE IF EXISTS `colaboradores`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `colaboradores` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `barbearia_id` int unsigned NOT NULL,
  `usuario_id` int unsigned NOT NULL,
  `ativo` tinyint(1) NOT NULL DEFAULT '1',
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_barbearia_usuario` (`barbearia_id`,`usuario_id`),
  KEY `idx_barbearia_id` (`barbearia_id`),
  KEY `idx_usuario_id` (`usuario_id`),
  CONSTRAINT `fk_colab_barbearia` FOREIGN KEY (`barbearia_id`) REFERENCES `barbearias` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_colab_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `colaboradores`
--

LOCK TABLES `colaboradores` WRITE;
/*!40000 ALTER TABLE `colaboradores` DISABLE KEYS */;
INSERT INTO `colaboradores` VALUES (1,1,2,1,'2026-06-01 20:53:33'),(2,1,16,0,'2026-06-10 23:31:02'),(3,1,17,1,'2026-06-11 16:05:52');
/*!40000 ALTER TABLE `colaboradores` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `horarios_bloqueados`
--

DROP TABLE IF EXISTS `horarios_bloqueados`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `horarios_bloqueados` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `colaborador_id` int unsigned NOT NULL,
  `data_hora_ini` datetime NOT NULL,
  `data_hora_fim` datetime NOT NULL,
  `motivo` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_colaborador_periodo` (`colaborador_id`,`data_hora_ini`,`data_hora_fim`),
  CONSTRAINT `fk_bloqueio_colaborador` FOREIGN KEY (`colaborador_id`) REFERENCES `colaboradores` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=91 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `horarios_bloqueados`
--

LOCK TABLES `horarios_bloqueados` WRITE;
/*!40000 ALTER TABLE `horarios_bloqueados` DISABLE KEYS */;
INSERT INTO `horarios_bloqueados` VALUES (1,3,'2026-06-12 12:00:00','2026-06-12 13:30:00','Almoço','2026-06-11 23:52:46'),(3,3,'2026-06-14 12:00:00','2026-06-14 13:30:00','Almoço','2026-06-11 23:52:46'),(4,3,'2026-06-15 12:00:00','2026-06-15 13:30:00','Almoço','2026-06-11 23:52:46'),(5,3,'2026-06-16 12:00:00','2026-06-16 13:30:00','Almoço','2026-06-11 23:52:46'),(6,3,'2026-06-17 12:00:00','2026-06-17 13:30:00','Almoço','2026-06-11 23:52:46'),(7,3,'2026-06-18 12:00:00','2026-06-18 13:30:00','Almoço','2026-06-11 23:52:46'),(8,3,'2026-06-19 12:00:00','2026-06-19 13:30:00','Almoço','2026-06-11 23:52:46'),(9,3,'2026-06-20 12:00:00','2026-06-20 13:30:00','Almoço','2026-06-11 23:52:46'),(10,3,'2026-06-21 12:00:00','2026-06-21 13:30:00','Almoço','2026-06-11 23:52:46'),(11,3,'2026-06-22 12:00:00','2026-06-22 13:30:00','Almoço','2026-06-11 23:52:46'),(12,3,'2026-06-23 12:00:00','2026-06-23 13:30:00','Almoço','2026-06-11 23:52:46'),(13,3,'2026-06-24 12:00:00','2026-06-24 13:30:00','Almoço','2026-06-11 23:52:46'),(14,3,'2026-06-25 12:00:00','2026-06-25 13:30:00','Almoço','2026-06-11 23:52:46'),(15,3,'2026-06-26 12:00:00','2026-06-26 13:30:00','Almoço','2026-06-11 23:52:46'),(16,3,'2026-06-27 12:00:00','2026-06-27 13:30:00','Almoço','2026-06-11 23:52:46'),(17,3,'2026-06-28 12:00:00','2026-06-28 13:30:00','Almoço','2026-06-11 23:52:46'),(18,3,'2026-06-29 12:00:00','2026-06-29 13:30:00','Almoço','2026-06-11 23:52:46'),(19,3,'2026-06-30 12:00:00','2026-06-30 13:30:00','Almoço','2026-06-11 23:52:46'),(20,3,'2026-07-01 12:00:00','2026-07-01 13:30:00','Almoço','2026-06-11 23:52:46'),(21,3,'2026-07-02 12:00:00','2026-07-02 13:30:00','Almoço','2026-06-11 23:52:46'),(22,3,'2026-07-03 12:00:00','2026-07-03 13:30:00','Almoço','2026-06-11 23:52:46'),(23,3,'2026-07-04 12:00:00','2026-07-04 13:30:00','Almoço','2026-06-11 23:52:46'),(24,3,'2026-07-05 12:00:00','2026-07-05 13:30:00','Almoço','2026-06-11 23:52:46'),(25,3,'2026-07-06 12:00:00','2026-07-06 13:30:00','Almoço','2026-06-11 23:52:46'),(26,3,'2026-07-07 12:00:00','2026-07-07 13:30:00','Almoço','2026-06-11 23:52:46'),(27,3,'2026-07-08 12:00:00','2026-07-08 13:30:00','Almoço','2026-06-11 23:52:46'),(28,3,'2026-07-09 12:00:00','2026-07-09 13:30:00','Almoço','2026-06-11 23:52:46'),(29,3,'2026-07-10 12:00:00','2026-07-10 13:30:00','Almoço','2026-06-11 23:52:46'),(30,3,'2026-07-11 12:00:00','2026-07-11 13:30:00','Almoço','2026-06-11 23:52:46'),(31,3,'2026-07-12 12:00:00','2026-07-12 13:30:00','Almoço','2026-06-11 23:52:46'),(32,3,'2026-07-13 12:00:00','2026-07-13 13:30:00','Almoço','2026-06-11 23:52:46'),(33,3,'2026-07-14 12:00:00','2026-07-14 13:30:00','Almoço','2026-06-11 23:52:46'),(34,3,'2026-07-15 12:00:00','2026-07-15 13:30:00','Almoço','2026-06-11 23:52:46'),(35,3,'2026-07-16 12:00:00','2026-07-16 13:30:00','Almoço','2026-06-11 23:52:46'),(36,3,'2026-07-17 12:00:00','2026-07-17 13:30:00','Almoço','2026-06-11 23:52:46'),(37,3,'2026-07-18 12:00:00','2026-07-18 13:30:00','Almoço','2026-06-11 23:52:46'),(38,3,'2026-07-19 12:00:00','2026-07-19 13:30:00','Almoço','2026-06-11 23:52:46'),(39,3,'2026-07-20 12:00:00','2026-07-20 13:30:00','Almoço','2026-06-11 23:52:46'),(40,3,'2026-07-21 12:00:00','2026-07-21 13:30:00','Almoço','2026-06-11 23:52:46'),(41,3,'2026-07-22 12:00:00','2026-07-22 13:30:00','Almoço','2026-06-11 23:52:47'),(42,3,'2026-07-23 12:00:00','2026-07-23 13:30:00','Almoço','2026-06-11 23:52:47'),(43,3,'2026-07-24 12:00:00','2026-07-24 13:30:00','Almoço','2026-06-11 23:52:47'),(44,3,'2026-07-25 12:00:00','2026-07-25 13:30:00','Almoço','2026-06-11 23:52:47'),(45,3,'2026-07-26 12:00:00','2026-07-26 13:30:00','Almoço','2026-06-11 23:52:47'),(46,3,'2026-07-27 12:00:00','2026-07-27 13:30:00','Almoço','2026-06-11 23:52:47'),(47,3,'2026-07-28 12:00:00','2026-07-28 13:30:00','Almoço','2026-06-11 23:52:47'),(48,3,'2026-07-29 12:00:00','2026-07-29 13:30:00','Almoço','2026-06-11 23:52:47'),(49,3,'2026-07-30 12:00:00','2026-07-30 13:30:00','Almoço','2026-06-11 23:52:47'),(50,3,'2026-07-31 12:00:00','2026-07-31 13:30:00','Almoço','2026-06-11 23:52:47'),(51,3,'2026-08-01 12:00:00','2026-08-01 13:30:00','Almoço','2026-06-11 23:52:47'),(52,3,'2026-08-02 12:00:00','2026-08-02 13:30:00','Almoço','2026-06-11 23:52:47'),(53,3,'2026-08-03 12:00:00','2026-08-03 13:30:00','Almoço','2026-06-11 23:52:47'),(54,3,'2026-08-04 12:00:00','2026-08-04 13:30:00','Almoço','2026-06-11 23:52:47'),(55,3,'2026-08-05 12:00:00','2026-08-05 13:30:00','Almoço','2026-06-11 23:52:47'),(56,3,'2026-08-06 12:00:00','2026-08-06 13:30:00','Almoço','2026-06-11 23:52:47'),(57,3,'2026-08-07 12:00:00','2026-08-07 13:30:00','Almoço','2026-06-11 23:52:47'),(58,3,'2026-08-08 12:00:00','2026-08-08 13:30:00','Almoço','2026-06-11 23:52:47'),(59,3,'2026-08-09 12:00:00','2026-08-09 13:30:00','Almoço','2026-06-11 23:52:47'),(60,3,'2026-08-10 12:00:00','2026-08-10 13:30:00','Almoço','2026-06-11 23:52:47'),(61,3,'2026-08-11 12:00:00','2026-08-11 13:30:00','Almoço','2026-06-11 23:52:47'),(62,3,'2026-08-12 12:00:00','2026-08-12 13:30:00','Almoço','2026-06-11 23:52:47'),(63,3,'2026-08-13 12:00:00','2026-08-13 13:30:00','Almoço','2026-06-11 23:52:47'),(64,3,'2026-08-14 12:00:00','2026-08-14 13:30:00','Almoço','2026-06-11 23:52:47'),(65,3,'2026-08-15 12:00:00','2026-08-15 13:30:00','Almoço','2026-06-11 23:52:47'),(66,3,'2026-08-16 12:00:00','2026-08-16 13:30:00','Almoço','2026-06-11 23:52:47'),(67,3,'2026-08-17 12:00:00','2026-08-17 13:30:00','Almoço','2026-06-11 23:52:47'),(68,3,'2026-08-18 12:00:00','2026-08-18 13:30:00','Almoço','2026-06-11 23:52:47'),(69,3,'2026-08-19 12:00:00','2026-08-19 13:30:00','Almoço','2026-06-11 23:52:47'),(70,3,'2026-08-20 12:00:00','2026-08-20 13:30:00','Almoço','2026-06-11 23:52:47'),(71,3,'2026-08-21 12:00:00','2026-08-21 13:30:00','Almoço','2026-06-11 23:52:47'),(72,3,'2026-08-22 12:00:00','2026-08-22 13:30:00','Almoço','2026-06-11 23:52:47'),(73,3,'2026-08-23 12:00:00','2026-08-23 13:30:00','Almoço','2026-06-11 23:52:47'),(74,3,'2026-08-24 12:00:00','2026-08-24 13:30:00','Almoço','2026-06-11 23:52:47'),(75,3,'2026-08-25 12:00:00','2026-08-25 13:30:00','Almoço','2026-06-11 23:52:47'),(76,3,'2026-08-26 12:00:00','2026-08-26 13:30:00','Almoço','2026-06-11 23:52:47'),(77,3,'2026-08-27 12:00:00','2026-08-27 13:30:00','Almoço','2026-06-11 23:52:47'),(78,3,'2026-08-28 12:00:00','2026-08-28 13:30:00','Almoço','2026-06-11 23:52:47'),(79,3,'2026-08-29 12:00:00','2026-08-29 13:30:00','Almoço','2026-06-11 23:52:47'),(80,3,'2026-08-30 12:00:00','2026-08-30 13:30:00','Almoço','2026-06-11 23:52:47'),(81,3,'2026-08-31 12:00:00','2026-08-31 13:30:00','Almoço','2026-06-11 23:52:47'),(82,3,'2026-09-01 12:00:00','2026-09-01 13:30:00','Almoço','2026-06-11 23:52:47'),(83,3,'2026-09-02 12:00:00','2026-09-02 13:30:00','Almoço','2026-06-11 23:52:47'),(84,3,'2026-09-03 12:00:00','2026-09-03 13:30:00','Almoço','2026-06-11 23:52:47'),(85,3,'2026-09-04 12:00:00','2026-09-04 13:30:00','Almoço','2026-06-11 23:52:47'),(86,3,'2026-09-05 12:00:00','2026-09-05 13:30:00','Almoço','2026-06-11 23:52:47'),(87,3,'2026-09-06 12:00:00','2026-09-06 13:30:00','Almoço','2026-06-11 23:52:47'),(88,3,'2026-09-07 12:00:00','2026-09-07 13:30:00','Almoço','2026-06-11 23:52:47'),(89,3,'2026-09-08 12:00:00','2026-09-08 13:30:00','Almoço','2026-06-11 23:52:47'),(90,3,'2026-09-09 12:00:00','2026-09-09 13:30:00','Almoço','2026-06-11 23:52:47');
/*!40000 ALTER TABLE `horarios_bloqueados` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `horarios_funcionamento`
--

DROP TABLE IF EXISTS `horarios_funcionamento`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `horarios_funcionamento` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `colaborador_id` int unsigned NOT NULL,
  `dia_semana` tinyint NOT NULL COMMENT '0=Dom, 1=Seg, ..., 6=Sab',
  `hora_inicio` time NOT NULL,
  `hora_fim` time NOT NULL,
  `ativo` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `idx_colaborador_dia` (`colaborador_id`,`dia_semana`),
  CONSTRAINT `fk_horario_colaborador` FOREIGN KEY (`colaborador_id`) REFERENCES `colaboradores` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `horarios_funcionamento`
--

LOCK TABLES `horarios_funcionamento` WRITE;
/*!40000 ALTER TABLE `horarios_funcionamento` DISABLE KEYS */;
INSERT INTO `horarios_funcionamento` VALUES (1,1,2,'09:00:00','18:00:00',1),(2,1,3,'09:00:00','18:00:00',1),(3,1,4,'09:00:00','18:00:00',1),(4,1,5,'09:00:00','18:00:00',1),(5,1,6,'09:00:00','20:00:00',1),(6,2,2,'09:00:00','18:00:00',1),(7,2,3,'09:00:00','18:00:00',1),(8,2,4,'09:00:00','18:00:00',1),(9,2,5,'09:00:00','18:00:00',1),(10,2,6,'09:00:00','18:00:00',1),(25,3,2,'09:00:00','18:00:00',1),(26,3,3,'09:00:00','18:00:00',1),(27,3,4,'09:00:00','18:00:00',1),(28,3,5,'09:00:00','18:00:00',1),(29,3,6,'09:00:00','18:00:00',1);
/*!40000 ALTER TABLE `horarios_funcionamento` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notificacoes`
--

DROP TABLE IF EXISTS `notificacoes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notificacoes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `usuario_id` int unsigned NOT NULL,
  `agendamento_id` int unsigned DEFAULT NULL,
  `tipo` enum('lembrete','cancelamento','confirmacao','bloqueio') COLLATE utf8mb4_unicode_ci NOT NULL,
  `titulo` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `mensagem` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `enviada` tinyint(1) NOT NULL DEFAULT '0',
  `enviada_em` datetime DEFAULT NULL,
  `agendada_para` datetime NOT NULL COMMENT 'Quando deve ser disparada',
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_notif_agendamento` (`agendamento_id`),
  KEY `idx_enviada_agendada` (`enviada`,`agendada_para`),
  KEY `idx_usuario_id` (`usuario_id`),
  CONSTRAINT `fk_notif_agendamento` FOREIGN KEY (`agendamento_id`) REFERENCES `agendamentos` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_notif_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notificacoes`
--

LOCK TABLES `notificacoes` WRITE;
/*!40000 ALTER TABLE `notificacoes` DISABLE KEYS */;
INSERT INTO `notificacoes` VALUES (1,15,1,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-11 10:14:45','2026-06-11 10:14:45'),(2,15,1,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-20 08:00:00','2026-06-11 10:14:45'),(3,15,2,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-11 10:22:16','2026-06-11 10:22:16'),(4,15,2,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-18 11:40:00','2026-06-11 10:22:16'),(5,15,3,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-11 10:25:04','2026-06-11 10:25:04'),(6,15,3,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-11 12:00:00','2026-06-11 10:25:04'),(7,15,2,'cancelamento','Agendamento cancelado','Seu agendamento foi cancelado.',0,NULL,'2026-06-11 15:50:10','2026-06-11 15:50:10'),(8,15,1,'cancelamento','Agendamento cancelado','Seu agendamento foi cancelado.',0,NULL,'2026-06-11 15:50:12','2026-06-11 15:50:12'),(9,15,4,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-12 00:02:17','2026-06-12 00:02:17'),(10,15,4,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-13 13:00:00','2026-06-12 00:02:17'),(11,15,5,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-12 00:05:03','2026-06-12 00:05:03'),(12,15,5,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-17 17:30:00','2026-06-12 00:05:03'),(13,15,6,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-12 00:05:18','2026-06-12 00:05:18'),(14,15,6,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-17 14:45:00','2026-06-12 00:05:18'),(15,15,7,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-12 00:05:40','2026-06-12 00:05:40'),(16,15,7,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-17 15:00:00','2026-06-12 00:05:40'),(17,15,8,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-12 00:12:35','2026-06-12 00:12:35'),(18,15,8,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-12 17:30:00','2026-06-12 00:12:35'),(19,15,9,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-12 17:51:35','2026-06-12 17:51:35'),(20,15,9,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-13 10:30:00','2026-06-12 17:51:35'),(21,15,10,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-12 17:57:31','2026-06-12 17:57:31'),(22,15,10,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-16 15:00:00','2026-06-12 17:57:31'),(23,15,11,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-13 02:43:41','2026-06-13 02:43:41'),(24,15,11,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-24 15:00:00','2026-06-13 02:43:41'),(25,15,12,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-13 02:43:57','2026-06-13 02:43:57'),(26,15,12,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-24 16:30:00','2026-06-13 02:43:57'),(27,18,13,'confirmacao','Agendamento confirmado!','Seu horário foi reservado com sucesso.',0,NULL,'2026-06-13 02:44:49','2026-06-13 02:44:49'),(28,18,13,'lembrete','Lembrete de agendamento','Você tem um horário marcado em 2 horas!',0,NULL,'2026-06-17 16:30:00','2026-06-13 02:44:49');
/*!40000 ALTER TABLE `notificacoes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `refresh_tokens`
--

DROP TABLE IF EXISTS `refresh_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `refresh_tokens` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `usuario_id` int unsigned NOT NULL,
  `token` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expira_em` datetime NOT NULL,
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `idx_token` (`token`(100)),
  KEY `idx_usuario_id` (`usuario_id`),
  CONSTRAINT `fk_token_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=58 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `refresh_tokens`
--

LOCK TABLES `refresh_tokens` WRITE;
/*!40000 ALTER TABLE `refresh_tokens` DISABLE KEYS */;
INSERT INTO `refresh_tokens` VALUES (2,1,'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwibm9tZSI6IkFkbWluaXN0cmFkb3IiLCJyb2xlIjoiYWRtaW4iLCJpYXQiOjE3ODAzNTc5MDIsImV4cCI6MTc4MDk2MjcwMn0.bCk8S4Kgo9WxF7iRX7fjkbzd6timyIbJx_WtuFdDXws','2026-06-08 20:51:43','2026-06-01 20:51:42'),(5,10,'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MTAsIm5vbWUiOiJCYXJiZWlybyBPZmljaWFsIiwicm9sZSI6ImJhcmJlaXJvIiwiaWF0IjoxNzgwNDE2MDgyLCJleHAiOjE3ODEwMjA4ODJ9.ysumURFZ1U04F5eNYolaKIe6B_exHnCE77Aq-hg8My4','2026-06-09 13:01:23','2026-06-02 13:01:22'),(57,15,'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MTUsIm5vbWUiOiJDbGllbnRlIFRlc3RlIiwicm9sZSI6ImNsaWVudGUiLCJpYXQiOjE3ODEzMjk3NTMsImV4cCI6MTc4MTkzNDU1M30.zUDDe10rIxoie4S704VI3fJrai7qcI30Fspe4Y21xe0','2026-06-20 05:49:13','2026-06-13 02:49:13');
/*!40000 ALTER TABLE `refresh_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicos`
--

DROP TABLE IF EXISTS `servicos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `servicos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `barbearia_id` int unsigned NOT NULL,
  `nome` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descricao` text COLLATE utf8mb4_unicode_ci,
  `preco` decimal(8,2) NOT NULL,
  `duracao_min` smallint unsigned NOT NULL COMMENT 'Duração em minutos',
  `ativo` tinyint(1) NOT NULL DEFAULT '1',
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atualizado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_barbearia_ativo` (`barbearia_id`,`ativo`),
  CONSTRAINT `fk_servico_barbearia` FOREIGN KEY (`barbearia_id`) REFERENCES `barbearias` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `servicos`
--

LOCK TABLES `servicos` WRITE;
/*!40000 ALTER TABLE `servicos` DISABLE KEYS */;
INSERT INTO `servicos` VALUES (10,1,'Corte Clássico',NULL,35.00,30,1,'2026-06-01 20:29:01','2026-06-01 20:29:01'),(11,1,'Corte + Barba',NULL,55.00,50,1,'2026-06-01 20:29:01','2026-06-01 20:29:01'),(12,1,'Barba',NULL,25.00,20,1,'2026-06-01 20:29:01','2026-06-01 20:29:01'),(13,1,'Corte','O clássico que nunca sai de moda. Corte tesoura ou máquina, finalizado com lavagem e modelagem com pomada premium. Ideal para manter o visual alinhado no dia a dia.',30.00,25,1,'2026-06-01 20:52:17','2026-06-01 20:53:03'),(14,1,'limpeza de pele',NULL,25.00,15,1,'2026-06-11 15:41:30','2026-06-11 15:41:30'),(15,1,'Cone hindu (limpeza de ouvido)',NULL,55.00,15,1,'2026-06-13 02:42:37','2026-06-13 02:42:37');
/*!40000 ALTER TABLE `servicos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nome` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `telefone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `senha_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('cliente','barbeiro','admin') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'cliente',
  `ativo` tinyint(1) NOT NULL DEFAULT '1',
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atualizado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `telefone` (`telefone`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_email` (`email`),
  KEY `idx_telefone` (`telefone`),
  KEY `idx_role` (`role`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuarios`
--

LOCK TABLES `usuarios` WRITE;
/*!40000 ALTER TABLE `usuarios` DISABLE KEYS */;
INSERT INTO `usuarios` VALUES (1,'Administrador','admin@barbearia.com','(41) 99999-0000','$2b$10$S9IAZH/8KtnZJAr/4RM6UelpEXuPSt3FnDnV6Xr17dUHllbuk4H9m','admin',1,'2026-05-31 18:58:10','2026-06-01 20:31:17'),(2,'Guilherme Skraba',NULL,'4199999999','$2b$10$t.MFnODROCvZBNXFwv0HJeXg52pu8mc/vEOZ5La8lFbvF7GZTjuk2','barbeiro',1,'2026-06-01 20:53:33','2026-06-01 20:53:33'),(3,'Barbeiro Teste','barbeiro@teste.com','41999999999','123456','barbeiro',1,'2026-06-02 11:33:06','2026-06-02 11:33:06'),(4,'Cliente Teste','cliente@teste.com','41888888888','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','cliente',1,'2026-06-02 11:33:06','2026-06-02 11:53:28'),(5,'marcelo',NULL,'419777777','$2b$10$9R55a8qjqZYStu/kxV/eIuO7D/AP.77DA6kC/8U7wbXUYbKHCbWHW','cliente',1,'2026-06-02 11:56:13','2026-06-02 11:56:13'),(10,'Barbeiro Oficial','barbeiro_oficial@teste.com','41991111111','$2b$10$knkfjfjP30z6MUEgBi5.du3Nr2YIcsivf0QYm73OQ8LUSzwYu.mya','barbeiro',1,'2026-06-02 12:14:38','2026-06-02 12:19:13'),(11,'Admin Oficial','admin_oficial@teste.com','41992222222','$2b$10$knkfjfjP30z6MUEgBi5.du3Nr2YIcsivf0QYm73OQ8LUSzwYu.mya','admin',1,'2026-06-02 12:14:38','2026-06-02 12:19:13'),(15,'Cliente Teste','cliente2@teste.com','(41) 98888-0002','$2b$10$S9IAZH/8KtnZJAr/4RM6UelpEXuPSt3FnDnV6Xr17dUHllbuk4H9m','cliente',1,'2026-06-10 22:55:51','2026-06-10 22:55:51'),(16,'jose Pedro ',NULL,'41998989898','$2b$10$8nCdFzv1xp1632CM9fy.XOup7eRrgF44GCMEVa57PEcykV3jOh4fi','barbeiro',0,'2026-06-10 23:31:02','2026-06-11 16:05:22'),(17,'andre gabriel',NULL,'4196969696','$2b$10$agFOhN4eNxNcEIdf4fRCaurpV9EvG3S39NnAaBBEsuKRCC1lP6BYa','barbeiro',1,'2026-06-11 16:05:52','2026-06-11 16:05:52'),(18,'cliente druci',NULL,'4198989898','$2b$10$HNjEcAIncheXyYqvKwXUBexwdBc6DL.LPfVL3a9zzKJ.ttEcg8y3.','cliente',1,'2026-06-13 02:44:25','2026-06-13 02:44:25');
/*!40000 ALTER TABLE `usuarios` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-06-13 17:13:07
