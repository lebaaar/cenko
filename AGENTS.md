# Cenko mobile application

Before continuing, make sure to check out the [README.md](README.md) for an overview and [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines. There you will find core features and basic commands.

## Docs
Most of the documentation is in the [docs](/docs) folder. Here are some important docs to check out before starting development:
- Database schema is documented in [db.md](/docs/db.md)
- Plans and limitations of the free tier are documented in [plans.md](/docs/plans.md)

## Do
- App uses the internet_connection_checker_plus package to check for internet connection. Loading indicators are used to signal connection status. Internet connection status is provided by [internet_status_provider.dart](lib/shared/providers/internet_status_provider.dart); providers watch it to re-fetch data on reconnect.
- If loading status is needed, you can pick from CircularProgressIndicator or the custom [AnimatedDots](lib/shared/widgets/animated_dots.dart) widget. The AnimatedDots widget is a simple widget that shows three dots that animate in a loop.
- All constants such as links, contacts...  should be defined in [constants.dart](lib/core/constants/constants.dart).
- Reads can be expensive, so if you need to read something from the database, try to read it once and store it in memory. For example, if you need to read the user's name, read it once and store it in a provider. Then you can use that provider to get the user's name whenever you need it.
- Every time you add a dependecy to `pubspec.yaml`, make sure depencies stay organized and sorted alphabetically.

## Don't
- Never use hardcoded colors, always use colors from the theme. If you need to add a new color, add it to the theme and use it from there. Colors are defined in [app_theme.dart](lib/app_theme.dart).
