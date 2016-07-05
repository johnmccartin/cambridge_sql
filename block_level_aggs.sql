DROP TABLE IF EXISTS john.spatial_blocks2010;
CREATE TABLE john.spatial_blocks2010 AS
  SELECT
    blocks.geoid10 geoid10,
    blocks.geom geom,
    blocks.aland10 aland10,
    blocks.awater10 awater10,
    Sum(abp.units) units,
    Sum(abp.res_gfa) res_gfa,
    Sum(abp.nonres_gfa) nonres_gfa,
    Sum(abp.tot_gfa) tot_gfa,
    Sum(abp.land_val) land_val,
    Sum(abp.imp_val) imp_val,
    Sum(abp.res_val) res_val,
    Sum(abp.nonres_val) nonres_val,
    Sum(abp.total_val) total_val
  FROM cambridge2014.demographics_blocks2010 blocks
  LEFT JOIN john.abp_gfa_val abp
  ON ST_Intersects(blocks.geom, abp.geom)
  GROUP BY blocks.geoid10, blocks.geom, blocks.aland10, blocks.awater10;
