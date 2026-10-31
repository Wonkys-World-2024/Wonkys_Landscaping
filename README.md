# Wonkys_Landscaping — GitHub source review v0.29.2

**STATUS: NOT CLEARED FOR PUBLIC PRODUCTION DEPLOYMENT.** This is a source-review package prepared from v0.29.0 with additional source hardening, **not** a tested public release.

## Features
Qbox landscaping career: mowing, leaves, hedges/topiary, flower beds, forestry, cargo, heavy logging, contracts, banking, XP and leaderboard.

## Dependencies
- FiveM / Qbox (`qbx_core`, `qbx_vehiclekeys`)
- `ox_lib`, `ox_target`, `ox_inventory`, `oxmysql`
- Third-party Bzzz garden, lumberjack and waste bag assets. **Not included** in this source archive. Obtain them from their original creator under applicable terms.

## Optional vehicles and external prop downloads

This resource was developed using specific vehicle models, but **you can substitute your own vehicles and props**. Replacements must use valid FiveM spawn names and may require adjusting trailer offsets, attachment logic, cargo layout, towing compatibility, and spawn positions. Merely changing a model name does not guarantee compatibility.

| Asset used during development | Where to obtain it | Configuration / notes |
| --- | --- | --- |
| **Bzzz Garden Pack** (flower beds, hedges, plants) | [Official free Garden Pack](https://bzzz.tebex.io/package/7028548) | Install as a separate dependency. Match `Config.Gardening` and hedge model names if substituting props. |
| **Bzzz Lumberjack Wood** | [Official free Lumberjack Wood pack](https://bzzz.tebex.io/package/5741954) | Used for logging visuals; check `Config.Logging.logPileModel` and heavy logging `logModel`. |
| **Bzzz Weed Bag / other props** | [Official Bzzz store](https://bzzz.tebex.io/category/wish) | Select the matching asset pack from the creator; verify model names before substituting. |
| **LNWK Sandstorm EV** (`sandstormev`) | [Aweetumn-LLC LNWK-CARS on GitHub](https://github.com/Aweetumn-LLC/FiveM-Lorefriendly-Vehicles/tree/main/LNWK-CARS) | Set `Config.Fleet.vanModel` and `Config.Fleet.vehicleOptions`. Replacement needs to tow your selected trailer. |
| **CO trailer** (`cotrailer`) | [Open Car Trailer on GTA5-Mods](https://www.gta5-mods.com/vehicles/open-car-trailer-add-on-v1-0) | Set `Config.Fleet.trailerModel`; re-check cargo placement offsets and hitch compatibility. |
| **GTA vehicles** (`mower`, `phantom`, `trflat`) | Included with GTA V / FiveM | Defaults for mower and heavy logging truck/trailer. Configure `Config.Fleet.mowerModel`, `Config.HeavyLogging.truckModel` / `trailerModel` as applicable. |

**Important:** `sandstormev` and `cotrailer` are not bundled with this repository. Download them separately from the linked sources and respect their licences. Check that your installed vehicle spawn names match the configuration.

To swap a vehicle, edit `config.lua` (the default values are shown below):

```lua
Config.Fleet.vanModel = 'sandstormev'
Config.Fleet.vehicleOptions = { { model = 'sandstormev', label = 'Sandstorm EV' } }
Config.Fleet.trailerModel = 'cotrailer'
Config.Fleet.mowerModel = 'mower'
```

For the heavy logging truck and trailer, find the `truckModel='phantom'` and `trailerModel='trflat'` entries under `Config.HeavyLogging` in `config.lua`. Cargo positioning and vehicle spawning are also implemented in the client/server Lua scripts; inspect those before substituting trailer dimensions.

See [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md) for licence and redistribution notes.

## Installation (development/review only)
1. Install supported dependencies and configure `ox_inventory` items required by `config.lua` and client/server scripts.
2. Obtain the required third-party models from their original distributors, confirm usage rights, and install their resources or stream files as authorised.
3. Run `sql/install.sql` against your server database after backing it up.
4. Set the server ACE permissions for admin commands after reviewing `SECURITY_REVIEW.md`.
5. Review `config.lua` for spawn points, job permissions, vehicle models and depot coordinates.
6. Place this folder under your server's resources and `ensure Wonkys_Landscaping` only in a staging server first.

**Bzzz YTYP references have been removed from the manifest.** Install the creator-provided resource(s) separately, with their required streaming/asset registration. The source archive is **not plug-and-play** without dependencies and configured inventory items.

## Security and publication
Read `SECURITY_REVIEW.md` and `THIRD_PARTY_ASSETS.md` before making the repository public. No claim of exploit-proof security or redistribution rights is made.

## License
**No open-source license granted by this package.** The original owner must select a license for their own code and verify rights for all included material before publishing. Do not apply a license to third-party Bzzz assets without permission.

## Release candidate status
This repository is **GitHub-uploadable for code review**, but is **not cleared as a secure public production release**. Read `SECURITY_REVIEW.md` before enabling it on a public server. No unverified third-party model files are bundled.


## Security release status (v0.29.2)

This is a **static-security-hardened review candidate**, not a penetration-tested production release. Vehicle spawning remains client-side, and trailer cargo is not persisted. See [SECURITY_REVIEW.md](SECURITY_REVIEW.md) before deploying to a public server. Enable `Config.RequireJob` where appropriate and test vehicle key grants (network ownership may migrate).
