use leptos::prelude::*;
use leptos_meta::{provide_meta_context};
use leptos_router::{
    components::{Route, Router, Routes},
    StaticSegment,
};

#[component]
pub fn App() -> impl IntoView {
    provide_meta_context();

    view! {
        <Router>
            <Routes fallback=move || "Not found.">
                <Route path=StaticSegment("") view=HomePage/>
                <Route path=StaticSegment("ssr") view=SsrPage/>
                <Route path=StaticSegment("ssr-performance-showdown") view=SsrPerformanceShowdown/>
            </Routes>
        </Router>
    }
}

/// Renders the SSR page of your application.
#[component]
fn SsrPage() -> impl IntoView {
    let items: Vec<u32> = (0..50).map(|_| 1).collect();

    view! {
        <main>
            {items
                .into_iter()
                .enumerate()
                .map(|(i, v)| {
                    view! { <div>"SSR " {v} "-" {i}</div> }
                })
                .collect_view()}
        </main>
    }
}

/// Renders the home page of your application.
#[component]
fn HomePage() -> impl IntoView {
    // Creates a reactive value to update the button
    let count = RwSignal::new(0);
    let on_click = move |_| *count.write() += 1;

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <button on:click=on_click>"Click Me: " {count}</button>
    }
}

#[component]
fn SsrPerformanceShowdown() -> impl IntoView  {
    let wrapper_width: f32 = 960.0;
    let wrapper_height: f32 = 720.0;
    let cell_size = 10.0;
    let center_x = wrapper_width / 2.0;
    let center_y = wrapper_height / 2.0;

    let mut angle: f32 = 0.0;
    let mut radius: f32 = 0.0;
    let mut tiles = Vec::new();
    let step = cell_size;

    while radius < (wrapper_width.min(wrapper_height) / 2.0) {
        let x = center_x + angle.cos() * radius;
        let y = center_y + angle.sin() * radius;

        if x >= 0.0 && x <= wrapper_width - cell_size && y >= 0.0 && y <= wrapper_height - cell_size
        {
            tiles.push((x, y));
        }

        angle += 0.2;
        radius += step * 0.015;
    }

    let tiles = tiles.into_iter().map(|(x, y)| view! { <div class="tile" style=format!("left: {x:.2}px; top: {y:.2}px")></div> }).collect_view();
    view! {
        <style>
            r#"body {
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                background-color: #f0f0f0;
                margin: 0;
            }
            #wrapper {
                width: 960px;
                height: 720px;
                position: relative;
                background-color: white;
            }
            .tile {
                position: absolute;
                width: 10px;
                height: 10px;
                background-color: #333;
            }"#
        </style>

        <div id="root">
            <div id="wrapper">{tiles}</div>
        </div>
    }
}