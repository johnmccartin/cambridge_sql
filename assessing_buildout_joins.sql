

#Assessing dept geoms, includes Buildout Maplot where geoms are equivalent
DROP TABLE IF EXISTS john.buildout_assessing_parceling;

CREATE TABLE john.buildout_assessing_parceling AS
  SELECT parcels.ml ml, buildout.maplot bo_ml, parcels.geom geom
  FROM john.parcels_fy15 parcels
  LEFT JOIN john.buildoutparcels_2014 buildout
  ON ST_EQUALS(parcels.geom, buildout.geom);

CREATE INDEX buildout_assessing_parceling_geom_idx
  ON john.buildout_assessing_parceling
  USING gist (geom);
  ##################################
  #### Success. Running time ~ 1min
  ##################################





# Buildout geoms, includes assessing maplot as array where assessing
# parcel centroid is within buildout parcel
DROP TABLE IF EXISTS john.assessing_buildout_parceling;

CREATE TABLE john.assessing_buildout_parceling AS
  SELECT buildout.ml maplot, array_agg(parcels.ml) ml_asr, buildout.geom geom
  FROM john.buildoutparcels_2014 buildout
  LEFT JOIN john.parcels_fy15 parcels
  ON ST_Contains(buildout.geom, ST_Centroid(parcels.geom));

CREATE INDEX assessing_buildout_parceling_geom_idx
  ON john.assessing_buildout_parceling
  USING gist (geom);
  ##################################
  #### Success. Running time ~ 20min
  ##################################





# Buildout geoms, includes assessing maplot as array where assessing
# parcel pointOnSurface is within buildout parcel
DROP TABLE IF EXISTS john.assessing_buildout_parceling2;

CREATE TABLE john.assessing_buildout_parceling2 AS
  SELECT buildout.ml maplot, array_agg(parcels.ml) ml_asr, buildout.geom geom
  FROM john.buildoutparcels_2014 buildout
  LEFT JOIN john.parcels_fy15 parcels
  ON ST_Contains(buildout.geom, ST_PointOnSurface(parcels.geom))
  GROUP BY buildout.ml, buildout.geom;

CREATE INDEX assessing_buildout_parceling_geom_idx
  ON john.assessing_buildout_parceling
  USING gist (geom);

##########################################
#### Success. Running time MANY MANY HOURS
##########################################
