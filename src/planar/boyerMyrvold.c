/*PGR-GNU*****************************************************************
File: boyerMyrvold.c
Generated with Template by:
Copyright (c) 2019 pgRouting developers
Mail: project@pgrouting.org
Function's developer:
Copyright (c) 2020 Himanshu Raj
Mail: raj.himanshu2@gmail.com
------
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
********************************************************************PGR-GNU*/

#include <stdbool.h>
#include "c_common/postgres_connection.h"
#include "utils/array.h"

#include "c_common/debug_macro.h"
#include "c_common/e_report.h"
#include "c_common/time_msg.h"

#include "c_common/edges_input.h"
#include "c_common/arrays_input.h"

#include "drivers/planar/boyerMyrvold_driver.h"

PGDLLEXPORT Datum _pgr_boyermyrvold(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(_pgr_boyermyrvold);

static void
process(
    char *edges_sql,

    pgr_boyer_t **result_tuples,
    size_t *planarity) {
    pgr_SPI_connect();

    PGR_DBG("Initializing arrays");


    (*result_tuples) = NULL;
    (*planarity) = 0;

    PGR_DBG("Load data");
    pgr_edge_t *edges = NULL;
    size_t total_edges = 0;

    pgr_get_edges(edges_sql, &edges, &total_edges);
    PGR_DBG("Total %ld edges in query:", total_edges);

    if (total_edges == 0) {
        *planarity = 2;
        pgr_SPI_finish();
        return;
    }

    PGR_DBG("Starting processing");
    clock_t start_t = clock();
    char *log_msg = NULL;
    char *notice_msg = NULL;
    char *err_msg = NULL;
    do_pgr_boyerMyrvold(
        edges,
        total_edges,

        result_tuples,
        planarity,

        &log_msg,
        &notice_msg,
        &err_msg);

    time_msg(" processing pgr_boyerMyrvold", start_t, clock());
    PGR_DBG("Returning %ld tuples", *planarity);

    if (err_msg) {
        if (*result_tuples)
            pfree(*result_tuples);
    }

    pgr_global_report(log_msg, notice_msg, err_msg);

    if (edges)
        pfree(edges);
    if (log_msg)
        pfree(log_msg);
    if (notice_msg)
        pfree(notice_msg);
    if (err_msg)
        pfree(err_msg);

    pgr_SPI_finish();
}

PGDLLEXPORT Datum _pgr_boyermyrvold(PG_FUNCTION_ARGS) {
      pgr_boyer_t *result_tuples = NULL;
      size_t planarity = 0;
      bool ans;
      PGR_DBG("Calling process");
      process(
          text_to_cstring(PG_GETARG_TEXT_P(0)),
          &result_tuples,
          &planarity);
      PGR_DBG("%ld",planarity);
      if(planarity == 1)
      PG_RETURN_BOOL(planarity);
      else if (planarity == 0)
      PG_RETURN_BOOL(planarity);
      else if(planarity == 2)
      PG_RETURN_NULL();
      PGR_DBG("Clean up code");
}
