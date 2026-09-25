use std::sync::{Arc, OnceLock};

use gpui::prelude::*;
use gpui::{
    Context, Entity, FontWeight, ObjectFit, Render, RenderImage, ScrollHandle,
    TextAlign, Window, div, img, px,
};
use ui::{ActiveTheme as _, Scrollbar, Scroller, Text};

fn app_logo() -> Arc<RenderImage> {
    static LOGO: OnceLock<Arc<RenderImage>> = OnceLock::new();
    LOGO.get_or_init(|| {
        let bytes = include_bytes!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../assets/images/app-logo.png"
        ));
        let decoded = image::load_from_memory(bytes).expect("valid app logo png");
        let rgba = decoded.to_rgba8();
        let frame = image::Frame::new(rgba);
        Arc::new(RenderImage::new(vec![frame]))
    })
    .clone()
}

fn azka_avatar() -> Arc<RenderImage> {
    static IMAGE: OnceLock<Arc<RenderImage>> = OnceLock::new();
    IMAGE
        .get_or_init(|| {
            let bytes = include_bytes!(concat!(
                env!("CARGO_MANIFEST_DIR"),
                "/../../assets/images/azka.jpg"
            ));
            let decoded = image::load_from_memory(bytes).expect("valid jpeg");
            let rgba = decoded.to_rgba8();
            let frame = image::Frame::new(rgba);
            Arc::new(RenderImage::new(vec![frame]))
        })
        .clone()
}

pub(crate) struct AboutView {
    scrollbar: Entity<Scrollbar>,
}

impl AboutView {
    pub(crate) fn new(cx: &mut Context<Self>) -> Self {
        let id = cx.entity_id();
        Self {
            scrollbar: cx.new(|_| Scrollbar::new(ScrollHandle::new()).watching(id)),
        }
    }
}

impl Render for AboutView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let theme = *cx.theme();
        let pad = theme.metrics.inset;

        div().flex().flex_col().size_full().child(
            Scroller::new("about", &self.scrollbar).p(pad).child(
                div()
                    .flex()
                    .flex_col()
                    .items_center()
                    .w_full()
                    .py_8()
                    .gap_6()
                    // 1. Official App Emblem / Logo
                    .child(
                        div()
                            .size(px(160.))
                            .overflow_hidden()
                            .border_1()
                            .border_color(theme.border)
                            .bg(theme.secondary)
                            .shadow_lg()
                            .child(
                                img(app_logo())
                                    .size_full()
                                    .object_fit(ObjectFit::Cover),
                            ),
                    )
                    // 2. Central Heading: "Uchan Music by AzkaaHPS"
                        div()
                            .flex()
                            .flex_col()
                            .items_center()
                            .gap_1()
                            .child(
                                div()
                                    .text_size(theme.text(Text::Display))
                                    .font_weight(FontWeight::BOLD)
                                    .text_color(theme.foreground)
                                    .text_align(TextAlign::Center)
                                    .child("Uchan Music by AzkaaHPS"),
                            )
                            .child(
                                div()
                                    .text_size(theme.text(Text::Small))
                                    .text_color(theme.muted_foreground)
                                    .text_align(TextAlign::Center)
                                    .child("Native Music Streaming Client - Built with Rust & GPUI"),
                            ),
                    )
                    .child(
                        div()
                            .flex()
                            .flex_col()
                            .w(px(520.))
                            .max_w_full()
                            .border_1()
                            .border_color(theme.border)
                            .bg(theme.secondary.opacity(0.35))
                            .p_6()
                            .gap_5()
                            .child(
                                div()
                                    .flex()
                                    .flex_col()
                                    .gap_3()
                                    .child(
                                        div()
                                            .text_size(theme.text(Text::Small))
                                            .font_weight(FontWeight::BOLD)
                                            .text_color(theme.muted_foreground)
                                            .child("CREATOR PROFILE"),
                                    )
                                    .child(
                                        div()
                                            .flex()
                                            .items_center()
                                            .gap_4()
                                            .pb_2()
                                            .child(
                                                div()
                                                    .size(px(72.))
                                                    .flex_none()
                                                    .overflow_hidden()
                                                    .border_1()
                                                    .border_color(theme.border)
                                                    .bg(theme.secondary)
                                                    .child(
                                                        img(azka_avatar())
                                                            .size_full()
                                                            .object_fit(ObjectFit::Cover),
                                                    ),
                                            )
                                            .child(
                                                div()
                                                    .flex()
                                                    .flex_col()
                                                    .gap_0p5()
                                                    .child(
                                                        div()
                                                            .font_weight(FontWeight::BOLD)
                                                            .text_size(theme.text(Text::Normal))
                                                            .text_color(theme.foreground)
                                                            .child("Azka Hafidzha Putra Septo"),
                                                    )
                                                    .child(
                                                        div()
                                                            .text_size(theme.text(Text::Small))
                                                            .text_color(theme.muted_foreground)
                                                            .child("Frontend Dev / AI Enthusiast / Vibecoder"),
                                                    )
                                                    .child(
                                                        div()
                                                            .text_size(theme.text(Text::Small))
                                                            .text_color(theme.muted_foreground)
                                                            .child("SMKS Taruna Bangsa"),
                                                    ),
                                            ),
                                    )
                                    .child(
                                        div()
                                            .flex()
                                            .items_center()
                                            .justify_between()
                                            .child(div().text_color(theme.muted_foreground).child("GitHub"))
                                            .child(
                                                div()
                                                    .font_weight(FontWeight::MEDIUM)
                                                    .text_color(theme.primary)
                                                    .cursor_pointer()
                                                    .on_click(|_, _, cx| cx.open_url("https://github.com/Azkaahps"))
                                                    .child("github.com/Azkaahps"),
                                            ),
                                    )
                                    .child(
                                        div()
                                            .flex()
                                            .items_center()
                                            .justify_between()
                                            .child(div().text_color(theme.muted_foreground).child("Instagram"))
                                            .child(
                                                div()
                                                    .font_weight(FontWeight::MEDIUM)
                                                    .text_color(theme.primary)
                                                    .cursor_pointer()
                                                    .on_click(|_, _, cx| cx.open_url("https://instagram.com/azkahps"))
                                                    .child("@azkahps / @roxy4rzz"),
                                            ),
                                    ),
                            )
                            .child(
                                div()
                                    .flex()
                                    .flex_col()
                                    .gap_3()
                                    .pt_4()
                                    .border_t_1()
                                    .border_color(theme.border)
                                    .child(
                                        div()
                                            .text_size(theme.text(Text::Small))
                                            .font_weight(FontWeight::BOLD)
                                            .text_color(theme.muted_foreground)
                                            .child("APPLICATION SPECIFICATIONS"),
                                    )
                                    .child(
                                        div()
                                            .flex()
                                            .items_center()
                                            .justify_between()
                                            .child(div().text_color(theme.muted_foreground).child("Version"))
                                            .child(div().font_weight(FontWeight::MEDIUM).text_color(theme.foreground).child("0.39.0 Custom")),
                                    )
                                    .child(
                                        div()
                                            .flex()
                                            .items_center()
                                            .justify_between()
                                            .child(div().text_color(theme.muted_foreground).child("UI Engine"))
                                            .child(div().font_weight(FontWeight::MEDIUM).text_color(theme.foreground).child("GPUI (Zed Industries)")),
                                    )
                                    .child(
                                        div()
                                            .flex()
                                            .items_center()
                                            .justify_between()
                                            .child(div().text_color(theme.muted_foreground).child("Design System"))
                                            .child(div().font_weight(FontWeight::MEDIUM).text_color(theme.foreground).child("Strict Unborder-Radius")),
                                    )
                                    .child(
                                        div()
                                            .flex()
                                            .items_center()
                                            .justify_between()
                                            .child(div().text_color(theme.muted_foreground).child("License"))
                                            .child(div().font_weight(FontWeight::MEDIUM).text_color(theme.foreground).child("GPL-3.0")),
                                    ),
                            )
                            .child(
                                div()
                                    .flex()
                                    .items_center()
                                    .justify_center()
                                    .gap_3()
                                    .pt_3()
                                    .child(
                                        div()
                                            .id("btn-open-repo")
                                            .flex()
                                            .items_center()
                                            .justify_center()
                                            .px_4()
                                            .py_2()
                                            .bg(theme.primary)
                                            .text_color(theme.primary_foreground)
                                            .text_size(theme.text(Text::Small))
                                            .font_weight(FontWeight::MEDIUM)
                                            .cursor_pointer()
                                            .hover(|s| s.bg(theme.primary_hover))
                                            .on_click(|_, _, cx| cx.open_url("https://github.com/Azkaahps/uchan-music"))
                                            .child("Open Repository on GitHub"),
                                    ),
                            ),
                    ),
            ),
        )
    }
}
