use leptos::prelude::*;
use leptos_meta::{provide_meta_context, Meta, MetaTags};
use leptos_router::components::A;
use leptos_router::{
    components::{Route, Router, Routes},
    SsrMode, StaticSegment, WildcardSegment,
};

use crate::components::app_layout::AppLayout;
use crate::components::faq_page::FaqPage;
use crate::components::get_started_page::GetStartedPage;
use crate::components::home_page::HomePage;
use crate::components::legal_page::{PrivacyPage, TermsPage};
use crate::components::page_meta::PageMeta;
use crate::components::support_page::SupportPage;

#[allow(dead_code)]
pub fn shell(options: LeptosOptions) -> impl IntoView {
    view! {
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <meta charset="utf-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <link rel="icon" href="/favicon.svg" type="image/svg+xml"/>
                <link rel="apple-touch-icon" href="/apple-touch-icon.png"/>
                <link rel="manifest" href="/site.webmanifest"/>
                <meta name="theme-color" content="#0d0d0f"/>
                <AutoReload options=options.clone()/>
                <HashedStylesheet options=options.clone()/>
                <EdgeHydrationScripts options=options/>
                <MetaTags/>
            </head>
            <body>
                <App/>
            </body>
        </html>
    }
}

#[component]
pub fn App() -> impl IntoView {
    provide_meta_context();

    view! {
        <Meta name="color-scheme" content="dark"/>

        <Router>
            <AppLayout>
                <Routes fallback=|| view! { <NotFoundPage/> }.into_view()>
                    <Route path=StaticSegment("") view=HomePage ssr=SsrMode::OutOfOrder/>
                    <Route path=StaticSegment("get-started") view=GetStartedPage ssr=SsrMode::OutOfOrder/>
                    <Route path=StaticSegment("privacy") view=PrivacyPage ssr=SsrMode::OutOfOrder/>
                    <Route path=StaticSegment("terms") view=TermsPage ssr=SsrMode::OutOfOrder/>
                    <Route path=StaticSegment("faq") view=FaqPage ssr=SsrMode::OutOfOrder/>
                    <Route path=StaticSegment("support") view=SupportPage ssr=SsrMode::OutOfOrder/>
                    // Must be last: guarantees deep links and hard refreshes get
                    // a full SSR HTML shell on the edge.
                    <Route path=WildcardSegment("any") view=NotFoundPage ssr=SsrMode::OutOfOrder/>
                </Routes>
            </AppLayout>
        </Router>
    }
}

#[component]
fn NotFoundPage() -> impl IntoView {
    #[cfg(feature = "ssr")]
    if let Some(response) = use_context::<leptos_axum::ResponseOptions>() {
        response.set_status(axum::http::StatusCode::NOT_FOUND);
    }

    view! {
        <PageMeta
            title="Page not found — MLXRead"
            description="The requested MLXRead page does not exist."
            path="/404"
        />
        <main class="shell">
            <section class="notfound">
                <p class="mono muted">"404"</p>
                <h1>"That page is not here."</h1>
                <A href="/" attr:class="btn btn--primary">"Back to MLXRead"</A>
            </section>
        </main>
    }
}

#[component]
fn HashedStylesheet(options: LeptosOptions) -> impl IntoView {
    let href = asset_href(&options, "css", crate::asset_hashes::CSS_HASH);

    view! {
        <link id="leptos" rel="stylesheet" href=href/>
    }
}

#[component]
fn EdgeHydrationScripts(options: LeptosOptions) -> impl IntoView {
    let js_href = asset_href(&options, "js", crate::asset_hashes::JS_HASH);
    let wasm_href = asset_href(&options, "wasm", crate::asset_hashes::WASM_HASH);
    let hydration_script = format!(
        "import({js_href:?}).then(mod => {{ mod.default({{ module_or_path: {wasm_href:?} }}).then(() => {{ mod.hydrate(); }}); }});"
    );

    view! {
        <link rel="modulepreload" href=js_href.clone()/>
        <link rel="preload" href=wasm_href.clone() r#as="fetch" r#type="application/wasm"/>
        <script type="module">{hydration_script}</script>
    }
}

fn asset_href(options: &LeptosOptions, extension: &str, hash: &str) -> String {
    let output_name = options.output_name.as_ref();
    let output_name = if output_name.is_empty() {
        env!("CARGO_PKG_NAME")
    } else {
        output_name
    };
    let pkg_dir = options.site_pkg_dir.as_ref();

    if hash.is_empty() {
        format!("/{pkg_dir}/{output_name}.{extension}")
    } else {
        format!("/{pkg_dir}/{output_name}.{hash}.{extension}")
    }
}
