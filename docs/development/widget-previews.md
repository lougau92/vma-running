# Flutter widget previews

Run flutter widget-preview start from the repository root, then filter by preview group in VS Code's Flutter Widget Preview panel. Flutter creates the local .widget_preview scaffold automatically; that generated directory is ignored.

The catalogue lives in lib/previews/. It previews the production widgets inside the app's French localization and Enjambée theme. Each ResponsivePreview creates a 390 × 844 phone entry and a 1100 × 900 desktop entry. Flutter's preview controls can switch brightness and zoom.

Preview inputs must be deterministic and synthetic. Use the shared builders in preview_data.dart and the service-free PreviewContentLoader; do not read bundled workout assets, real email, Firebase, preferences, or platform package information. For screens that need platform data, preview the controlled presentation widget.

When adding a scenario, give it a short feature group and state name, use the shared app wrapper unless the state needs a custom one, register its builder in preview_catalog.dart, and add it to the render checks in test/workout_previews_test.dart. Add interaction checks when the preview represents an editable control. Keep the catalogue focused on screens and states that help review real behavior; private layout helpers are covered through their parent widgets.

The test suite renders every registered scenario at phone and desktop sizes, checks settings with large text across supported languages and themes, and exercises representative interactions. Visual review stays manual; preview tests do not create golden images.
