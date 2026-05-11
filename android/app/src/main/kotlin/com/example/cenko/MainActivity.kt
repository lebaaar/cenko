package com.lebaaar.cenko

import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.ModelPreference
import com.google.mlkit.genai.prompt.ModelReleaseStage
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generationConfig
import com.google.mlkit.genai.prompt.generateContentRequest
import com.google.mlkit.genai.prompt.modelConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
	private val receiptAiScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
	private var receiptModel: GenerativeModel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECEIPT_AI_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"extractReceiptJsonFromOcr" -> {
					val prompt = call.argument<String>("prompt")?.trim().orEmpty()
					if (prompt.isEmpty()) {
						result.error("invalid_args", "prompt is required", null)
						return@setMethodCallHandler
					}

					receiptAiScope.launch {
						try {
							val extracted = extractReceiptJsonFromOcr(prompt)
							withContext(Dispatchers.Main) {
								result.success(extracted)
							}
						} catch (error: GenAiException) {
							withContext(Dispatchers.Main) {
								result.error("aicore_error", error.message ?: "Gemini Nano request failed", mapOf("errorCode" to error.errorCode))
							}
						} catch (error: Exception) {
							withContext(Dispatchers.Main) {
								result.error("aicore_unavailable", error.message ?: "Gemini Nano is unavailable on this device", null)
							}
						}
					}
				}

				else -> result.notImplemented()
			}
		}
	}

	override fun onDestroy() {
		receiptModel?.close()
		receiptModel = null
		receiptAiScope.cancel()
		super.onDestroy()
	}

	private fun getReceiptModel(): GenerativeModel {
		return receiptModel ?: Generation.getClient(
			generationConfig {
				modelConfig = modelConfig {
					releaseStage = ModelReleaseStage.STABLE
					preference = ModelPreference.FULL
				}
			},
		).also { receiptModel = it }
	}

	private suspend fun extractReceiptJsonFromOcr(prompt: String): String {
		val model = getReceiptModel()
		when (model.checkStatus()) {
			FeatureStatus.UNAVAILABLE -> throw IllegalStateException("Gemini Nano is unavailable on this device")
			FeatureStatus.DOWNLOADABLE,
			FeatureStatus.DOWNLOADING,
			-> {
				model.download().collect { status ->
					when (status) {
						is DownloadStatus.DownloadFailed -> throw status.e
						else -> Unit
					}
				}
			}
			FeatureStatus.AVAILABLE -> Unit
		}

		val response = model.generateContent(
			generateContentRequest(TextPart(prompt)) {
				temperature = 0.0f
				topK = 1
				candidateCount = 1
				maxOutputTokens = 2048
			},
		)

		return response.candidates.firstOrNull()?.text?.trim().orEmpty()
			.removePrefix("```json").removeSuffix("```").trim()
			.ifBlank {
				throw IllegalStateException("Gemini Nano returned an empty response")
			}
	}

	private companion object {
		private const val RECEIPT_AI_CHANNEL = "cenko/receipt_ai"
	}
}
