package com.example.lcc

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Android native PDF -> JPEG renderer for OCR.
 *
 * Uses android.graphics.pdf.PdfRenderer (API 21+).
 * Does NOT support password-protected PDFs (PdfRenderer can't open them).
 */
class PdfOcrRenderer : MethodChannel.MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        "pageCount" -> {
          val path = call.argument<String>("path")
          if (path.isNullOrBlank()) {
            result.error("bad_args", "Missing 'path'", null)
            return
          }
          result.success(getPageCount(path))
        }
        "renderPage" -> {
          val path = call.argument<String>("path")
          val pageIndex = call.argument<Int>("pageIndex") ?: 0
          val scale = (call.argument<Double>("scale") ?: 2.0).toFloat()
          val jpegQuality = call.argument<Int>("jpegQuality") ?: 92
          if (path.isNullOrBlank()) {
            result.error("bad_args", "Missing 'path'", null)
            return
          }
          result.success(renderPageJpeg(path, pageIndex, scale, jpegQuality))
        }
        else -> result.notImplemented()
      }
    } catch (e: Exception) {
      result.error("exception", e.message ?: "PDF render failed", e.toString())
    }
  }

  private fun getPageCount(path: String): Int {
    val file = File(path)
    val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    val renderer = PdfRenderer(pfd)
    val count = renderer.pageCount
    renderer.close()
    pfd.close()
    return count
  }

  private fun renderPageJpeg(
    path: String,
    pageIndex: Int,
    scale: Float,
    jpegQuality: Int
  ): ByteArray {
    val file = File(path)
    val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    val renderer = PdfRenderer(pfd)

    val safeIndex = pageIndex.coerceIn(0, renderer.pageCount - 1)
    val page = renderer.openPage(safeIndex)

    val targetW = (page.width * scale).toInt().coerceAtLeast(1)
    val targetH = (page.height * scale).toInt().coerceAtLeast(1)

    val bitmap = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
    bitmap.eraseColor(Color.WHITE)

    val matrix = Matrix()
    matrix.postScale(scale, scale)
    page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

    val baos = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, jpegQuality.coerceIn(50, 100), baos)
    val bytes = baos.toByteArray()
    baos.close()

    bitmap.recycle()
    page.close()
    renderer.close()
    pfd.close()

    return bytes
  }
}

