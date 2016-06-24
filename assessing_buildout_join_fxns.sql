/* ===================================================

  Join the buildout data to <abp> - the buildout
  geoms with assessors maplots joined to it.

==================================================== */


DROP TABLE IF EXISTS john.abp_gfa;
CREATE TABLE john.abp_gfa AS
  SELECT
    abp.*,
    gfa.hood,
    gfa.location,
    gfa.placename,
    gfa.owner
    gfa.usecode,
    gfa.descript,
    gfa.mutype,
    gfa.condo,
    gfa.taxstatus,
    gfa.landarea,
    gfa.units,
    gfa.rmghse_units,
    gfa.res_gfa,
    gfa.nonres_gfa,
    gfa.tot_gfa,
    gfa.far,
    gfa.underconst,
    gfa.yr_blt
  FROM john.assessing_buildout_parceling abp
  LEFT JOIN john.citywide_gfa gfa
  ON abp.maplot = gfa.maplot;

DROP INDEX IF EXISTS abp_gfa_geom_idx;

CREATE INDEX abp_gfa_geom_idx
  ON john.abp_gfa
  USING gist (geom);



ALTER TABLE john.abp_gfa
  ADD COLUMN gfa_diff integer;

UPDATE TABLE john.abp_gfa
  SET gfa_diff = tot_gfa - (res_gfa + nonres_gfa);






/* ===================================================
    This syncs the assessing data with the
    the residential designation based on the
    assessing account's use code.

    <rescode> is a faux boolean for residential
    vs. non-residential (N/NR).

    Rerun this code whenever your update the lookup
    table that assigns a rescode to a use_code.
==================================================== */
UPDATE john.assessing2015 a
  SET a.rescode = lookup.rescode
  FROM john.usecode_lookup lookup
  WHERE a.use_code = lookup.usecode;



/* ===================================================
    This aggregates the assessing data by maplot
    and by rescode. This way, for each parcel, you
    can calculate the total residential and total
    non-residential assessed valuation.
=================================================== */

DROP TABLE IF EXISTS john.assessing2015_agg2;
CREATE TABLE john.assessing2015_agg2 AS
  SELECT
    maplot,
    array_agg(acct_num) acct_num,
    array_agg(hood) hood,
    array_agg(location) location,
    array_agg(bldg_num) bldg_num,
    array_agg(bldg_typ) bldg_typ,
    array_agg(use_code) use_code,
    Max(land_area) land_area,
    array_agg(bldg_stories) bldg_stories,
    Sum(living_area) living_area,
    array_agg(yr_built) yr_built,
    array_agg(yr_code) yr_code,
    array_agg(style_desc) style_desc,
    array_agg(grade) grade,
    array_agg(ext_wall) ext_wall,
    Sum(beds) beds,
    Sum(baths) baths,
    Max(land_val) land_val,
    Sum(total_val) total_val,
    array_agg(owner) owner,
    array_agg(owner2) owner2,
    array_agg(own_mail) own_mail,
    array_agg(own_city) own_city,
    array_agg(own_state) own_state,
    array_agg(own_zip2) own_zip,
    rescode;
  FROM john.assessing2015
  GROUP BY maplot, rescode;


/* ===================================================
    Add columns for the improvement value,
    residential value, and nonresidential value.
    Set those based on the rescode defined above.
=================================================== */

ALTER TABLE john.assessing2015_agg2
  ADD COLUMN imp_val bigint;

ALTER TABLE john.assessing2015_agg2
  ADD COLUMN res_val bigint;

ALTER TABLE john.assessing2015_agg2
  ADD COLUMN nonres_val bigint;

UPDATE john.assessing2015_agg2
  SET imp_val = total_val - land_val;

UPDATE john.assessing2015_agg2
  SET res_val = imp_val
  WHERE rescode = 'R';

UPDATE john.assessing2015_agg2
  SET nonres_val = imp_val
  WHERE rescode = 'NR';







/* ===================================================
  Now that we have residential and non-residential
  values broken out as their own columns, aggregate
  the assessment layer by maplot.

  Note: there's a lot of info we're not aggregating
  here. This is due to my own ignorance. Postgres
  is throwing errors when I try to run its array
  functions over arrays (those previously
  constructed through array_agg). Ideally would run
  array_cat, but array_agg would be workable.

  Also tried to construct a WITH subquery, but
  didn't really know what I was doing.

  In any event, those vars aren't so pressing
  at the moment. Having building stories would
  be good, but we can also grab elevations from
  the building footprints data.

=================================================== */


DROP TABLE IF EXISTS john.assessing2015_agg_vals;
CREATE TABLE john.assessing2015_agg_vals AS
  /*
  (
  WITH
    bldg_stories_asr AS (
        SELECT array_agg(stories)
        FROM (
          SELECT maplot, unnest(bldg_stories)
          FROM john.assessing2015_agg2
        ) AS stories
    ) -- /bldg_stories_asr

  */

  SELECT
    maplot maplot_asr,
    Sum(living_area) living_area_asr,
    Sum(beds) beds,
    Sum(baths) baths,
    Max(land_val) land_val,
    Sum(total_val) total_val,
    Sum(imp_val) imp_val,
    Sum(res_val) res_val,
    Sum(nonres_val) nonres_val
    --array_agg(loc) loc,
    --array_agg(use_code) use_code,
    --array_agg(bldg_stories) bldg_stories_asr,
    --array_cat(bldg_stories) bldg_stories_asr,
    --bldg_stories_asr,
    --array_agg(yr_built) yr_built,
  FROM john.assessing2015_agg2 agg2
  GROUP BY maplot;
--); -- /WITH



/* ===================================================
    Join the aggregated values to the buildout
    parcels. Sum all the values, so that parcels
    in cases where buildout parcels include multiple
    assessment parcels, the figures reflect the
    land assembly.

    nb: it looks like the assessor's data already
    reflects many of the changes seen in the
    buildout data and geometry but not seen in the
    assessment geometry. e.g. when we spatial joined
    assessor's maplots to buildout maplots, we found
    multiple assessor's maplots for each buildout
    maplot where land had been assembled; but in
    the assessor's data, it seems many of those old
    parcel maplots have already been removed from
    the db.
=================================================== */


DROP TABLE IF EXISTS john.abp_val;
CREATE TABLE john.abp_val AS
  SELECT
    abp.maplot,
    abp.ml_asr,
    abp.geom,
    array_agg(abp.match_type),
    Sum(asr.living_area_asr) living_area_asr,
    Sum(asr.beds) beds,
    Sum(asr.baths) baths,
    Sum(asr.land_val) land_val,
    Sum(asr.imp_val) imp_val,
    Sum(asr.res_val) res_val,
    Sum(asr.nonres_val) nonres_val,
    Sum(asr.total_val) total_val
  FROM john.assessing_buildout_parceling abp
  LEFT JOIN john.assessing2015_agg_vals asr
  ON asr.maplot_asr IN (
    SELECT(
      unnest(abp.ml_asr)
    )
  )
  GROUP BY abp.maplot, abp.ml_asr, abp.geom;

DROP INDEX IF EXISTS abp_val_geom_idx;
CREATE INDEX abp_val_geom_idx
  ON john.abp_val
  USING gist (geom);


/* ===================================================
    Join buildout (gfa) and assessors data (val)
    into one table.
=================================================== */


DROP TABLE IF EXISTS john.abp_gfa_val;
CREATE TABLE john.abp_gfa_val AS
  SELECT
    gfa.*,
    val.living_area_asr,
    val.beds,
    val.baths,
    val.land_val,
    val.imp_val,
    val.res_val,
    val.nonres_val,
    val.total_val
  FROM john.abp_gfa gfa
  LEFT JOIN john.abp_val val
  ON gfa.maplot = val.maplot;


DROP INDEX IF EXISTS abp_gfa_val_geom_idx;
CREATE INDEX abp_gfa_val_geom_idx
  ON john.abp_gfa_val
  USING gist (geom);

/* ===================================================
    Analyze the consistency between assessor's
    and buildout data. i.e. Where does buildout show
    residential/non-residential space but the assessor
    has no valuation listed (or vice versa)?
=================================================== */

--nonres
--count consistent
SELECT Count(maplot)
  FROM john.abp_gfa_val
  WHERE nonres_gfa > 0
  AND (
    nonres_val IS NOT NULL
    AND
    nonres_val > 0
  );

--count inconsistent, gfa empty
SELECT Count(maplot)
	FROM john.abp_gfa_val
	WHERE nonres_gfa = 0
	AND nonres_val IS NOT NULL;

--count inconsistent, val empty
SELECT Count(maplot)
  FROM john.abp_gfa_val
  WHERE nonres_gfa > 0
  AND (
    nonres_val IS NULL
    OR
    nonres_val = 0
  );


--res
--count consistent
SELECT Count(maplot)
  FROM john.abp_gfa_val
  WHERE res_gfa > 0
  AND (
    res_val IS NOT NULL
    AND
    res_val > 0
  );

--count inconsistent, gfa empty
SELECT Count(maplot)
	FROM john.abp_gfa_val
	WHERE res_gfa = 0
	AND res_val IS NOT NULL;

--count inconsistent, val empty
SELECT Count(maplot)
  FROM john.abp_gfa_val
  WHERE res_gfa > 0
  AND (
    res_val IS NULL
    OR
    res_val = 0
  );
