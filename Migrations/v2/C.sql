
-- Some of this script modified from https://stackoverflow.com/questions/6121917/automatic-rollback-if-commit-transaction-is-not-reached

delimiter //
create procedure migration()
begin 
   DECLARE exit handler for sqlexception
      BEGIN
      
      GET DIAGNOSTICS CONDITION 1 @p1 = RETURNED_SQLSTATE, @p2 = MESSAGE_TEXT;
	  SELECT @p1, @p2, "ERROR999";
     
      ROLLBACK;
   END;

   DECLARE exit handler for sqlwarning
     BEGIN
      GET DIAGNOSTICS CONDITION 1 @p1 = RETURNED_SQLSTATE, @p2 = MESSAGE_TEXT;
	  SELECT @p1, @p2, "ERROR999";
	  
     ROLLBACK;
   END;
   
   START TRANSACTION;

INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, '15BB1FAE-D5E5-4694-AE36-04D003802E18');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, '2BC25814-FED5-441E-9B6D-3355E6BE367E');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'write', NULL, '5559BB4F-F232-4633-8C55-A031DFF5FCFE');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, '60A52DB4-39A8-486A-976C-A1DE0C922919');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, '67BFA324-5FD5-4547-844E-BE1616A71C64');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, '8A02F515-616A-421C-B797-2C72A7F23C63');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, '9E3884E1-BF93-4588-BDE8-E0DAF3B1D567');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, 'AC71AF5A-17C8-4E4D-B8D7-961892CDC1B0');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, 'B0D8A2A1-F476-4032-93CF-DED70D27CE3A');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, 'E8355EE7-B55C-4D03-B6E0-27EADD760CDF');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, 'ED194370-4AC4-4A19-A7D9-10F2481CCC77');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, 'EF8B6DB2-9469-4F0B-BB53-B12C14735BA5');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'admin', NULL, 'F03972D9-1DB7-4CA9-8037-2225180093FD');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('1', 'write', NULL, 'F7D59832-A829-4A2C-B464-394D5ED00485');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, '15BB1FAE-D5E5-4694-AE36-04D003802E18');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, '2BC25814-FED5-441E-9B6D-3355E6BE367E');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, '5559BB4F-F232-4633-8C55-A031DFF5FCFE');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, '60A52DB4-39A8-486A-976C-A1DE0C922919');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, '67BFA324-5FD5-4547-844E-BE1616A71C64');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, '8A02F515-616A-421C-B797-2C72A7F23C63');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, '9E3884E1-BF93-4588-BDE8-E0DAF3B1D567');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, 'AC71AF5A-17C8-4E4D-B8D7-961892CDC1B0');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, 'B0D8A2A1-F476-4032-93CF-DED70D27CE3A');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, 'E8355EE7-B55C-4D03-B6E0-27EADD760CDF');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, 'ED194370-4AC4-4A19-A7D9-10F2481CCC77');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, 'F03972D9-1DB7-4CA9-8037-2225180093FD');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('3', 'admin', NULL, 'F7D59832-A829-4A2C-B464-394D5ED00485');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'write', NULL, '15BB1FAE-D5E5-4694-AE36-04D003802E18');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, '2BC25814-FED5-441E-9B6D-3355E6BE367E');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'write', NULL, '5559BB4F-F232-4633-8C55-A031DFF5FCFE');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, '60A52DB4-39A8-486A-976C-A1DE0C922919');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, '67BFA324-5FD5-4547-844E-BE1616A71C64');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, '8A02F515-616A-421C-B797-2C72A7F23C63');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, '9E3884E1-BF93-4588-BDE8-E0DAF3B1D567');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, 'AC71AF5A-17C8-4E4D-B8D7-961892CDC1B0');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, 'B0D8A2A1-F476-4032-93CF-DED70D27CE3A');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, 'E8355EE7-B55C-4D03-B6E0-27EADD760CDF');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'write', NULL, 'ED194370-4AC4-4A19-A7D9-10F2481CCC77');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'admin', NULL, 'F03972D9-1DB7-4CA9-8037-2225180093FD');
INSERT INTO SharingGroupUser (userId, permission, owningUserId, sharingGroupUUID) VALUES ('4', 'write', NULL, 'F7D59832-A829-4A2C-B464-394D5ED00485');

		SELECT "SUCCESS123";
		
   COMMIT;
   
end//
delimiter ;

-- Not needed because the command line invocation of mysql specifies the database.
-- Use SyncServer_SharedImages;

call migration();
drop procedure migration;

