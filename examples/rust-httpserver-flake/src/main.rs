// From https://hyper.rs/guides/server/hello-world/

use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};
use log::info;
use std::{convert::Infallible, net::SocketAddr};

async fn handle(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    info!("Responding");
    Ok(Response::new(
        "Hello buildkit-nix/examples/rust-httpserver\n".into(),
    ))
}

#[tokio::main]
async fn main() {
    env_logger::init_from_env(
        env_logger::Env::default().filter_or(env_logger::DEFAULT_FILTER_ENV, "info"),
    );
    let addr: SocketAddr = "0.0.0.0:80".parse().unwrap();
    info!("Starting up, addr={}", addr);

    let make_svc = make_service_fn(|_conn| async { Ok::<_, Infallible>(service_fn(handle)) });

    let server = Server::bind(&addr).serve(make_svc);

    if let Err(e) = server.await {
        eprintln!("server error: {}", e);
    }
}
