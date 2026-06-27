---
name: rust-gtk4-expert
description: Expert guidance on building modern, robust Linux desktop applications with Rust, GTK4, and Libadwaita. Use this skill when the user asks for help with UI development, widget implementation, state management, or architecture in a GTK4/Rust project.
license: MIT
---

# Rust GTK4 Expert

This skill provides expert patterns and practices for building high-quality Linux desktop applications using Rust, GTK4, and Libadwaita.

## Core Architecture Patterns

### 1. The Factory Pattern for Components
Avoid monolithic `main.rs` files. Split UI components into separate files using the Factory pattern or GObject subclassing.

**Preferred Approach (Function-based Components - Simpler):**
Create functions that return widgets or tuples of widgets/controllers.

```rust
// src/components/header_bar.rs
use gtk4::prelude::*;
use libadwaita as adw;

pub fn create_header_bar() -> adw::HeaderBar {
    let header_bar = adw::HeaderBar::new();
    // Configure header bar...
    header_bar
}
```

**Advanced Approach (GObject Subclassing - More Powerful):**
Use `glib::subclass` when you need custom signals, properties, or complex internal state.

### 2. State Management
Use `Rc<RefCell<AppState>>` for shared mutable state in simple apps. For complex apps, consider the "Model-View-Update" (MVU) pattern (like Relm4) or a centralized `AppModel` using GObject properties.

**Standard Pattern:**
```rust
struct AppState {
    counter: i32,
}

let state = Rc::new(RefCell::new(AppState { counter: 0 }));

button.connect_clicked(glib::clone!(@strong state => move |_| {
    let mut s = state.borrow_mut();
    s.counter += 1;
    println!("Counter: {}", s.counter);
}));
```

### 3. Async UI and Concurrency
**NEVER block the main thread.**
Use `glib::MainContext::default().spawn_local()` for async operations that interact with the UI.
Use `std::thread` for CPU-bound tasks, communicating results back to the main thread via `glib::Sender` or `async_channel` integration.

## UI Design Guidelines (Libadwaita)

- **Adaptive Design:** Use `adw::Clamp`, `adw::Leaflet`, or `adw::OverlaySplitView` to support mobile and desktop layouts.
- **Modern Widgets:** Prefer `adw::StatusPage` for empty states, `adw::PreferencesWindow` for settings.
- **Styling:** Use CSS classes (`.title-1`, `.accent`, `.success`) instead of hardcoded styles.

## Common Pitfalls

- **Memory Leaks:** Watch out for reference cycles with `Rc`. Use `glib::clone!` with `@weak` references for closures connected to widgets that outlive the closure.
- **Incorrect Threading:** GTK widgets are **not click-safe** (except where noted). Always manipulate UI widgets from the main thread.

## Testing
- Unit test logic that is decoupled from widgets.
- For UI testing, use accessibility APIs or dedicated testing tools like `dogtail` (external) or `gtk4::test`.
