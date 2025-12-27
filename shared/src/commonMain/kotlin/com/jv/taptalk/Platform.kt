package com.jv.taptalk

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform