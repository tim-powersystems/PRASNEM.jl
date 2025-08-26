# NEM Reliability Suite: Example data

## Directory Structure

| Directory       | Description | Date range |
|-----------------|-------------|-------------|
| `nem12/`        | Root folder for NEM12 time-static parameters | |
| `schedule-1w/`  | 1 week time varying data - 168 timesteps | `2025-01-07 00:00:00` - `2025-01-13 23:00:00`|
| `schedule-24h/` | 24 hours time varying data - 24 timesteps | `2025-01-20 00:00:00` - `2025-01-20 23:00:00`|

## Files description

> [!NOTE] 
> **NEM12**: Time-static information
> - Bus
> - Demand
> - ESS
> - Generator_commitment
>   - *Unit commitment parameters for thermal units*
> - Generator
> - Line
>

### Time-varying parameters

> [!IMPORTANT] 
> **Schedule**: Time-varying parameters
> - Demand_load_sched: `value` load (MW) at a given `date`. Match with column `load_` from Demand
> - ESS_emax_sched: `value` emax (MWh) starting at a given `date`. Match with column `emax` from ESS
>   - `emax`: Maximum storage energy (MWh).
> - ESS_lmax_sched: `value` lmax (MW) starting at a given `date`. Match with column `lmax` from ESS
>   - `lmax`: Maximum storage charge input (MW) *[as a load]*.
> - ESS_pmax_sched: `value` pmax (MW) starting at a given `date`. Match with column `pmax` from ESS
>   - `pmax`: Maximum storage discharge output (MW).
> - Generator_pmax_sched: `value` pmax (MW) at a given `date`. Match with column `pmax` from Generator
>   - `pmax`: Maximum generator output (MW).
> - Generator_n_sched: `value` n (p.u.) starting at a given `date`. Match with column `n` from Generator
>   - `n`: Maximum number of online units
> - Line_tmax_sched: `value` tmax (MW) starting at a given `date`. Match with column `tmax` from Line
>   - `tmax`: Maximum line forward rating (MW)
> - Line_tmin_sched: `value` tmin (MW) starting at a given `date`. Match with column `tmin` from Line
>   - `tmin`: Maximum line reverse rating (MW)
>

