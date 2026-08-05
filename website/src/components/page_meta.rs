use leptos::prelude::*;
use leptos_meta::{Link, Meta, Title};

pub const SITE_ORIGIN: &str = "https://mlxread.com";

#[component]
pub fn PageMeta(
    #[prop(into)] title: String,
    #[prop(into)] description: String,
    #[prop(into)] path: String,
) -> impl IntoView {
    let canonical = format!("{SITE_ORIGIN}{path}");

    view! {
        <Title text=title.clone()/>
        <Meta name="description" content=description.clone()/>
        <Meta property="og:title" content=title/>
        <Meta property="og:description" content=description/>
        <Meta property="og:type" content="website"/>
        <Meta property="og:url" content=canonical.clone()/>
        <Link rel="canonical" href=canonical/>
    }
}
