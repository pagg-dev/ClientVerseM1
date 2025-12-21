/**
 * @description
 * Utility class for encrypting and decrypting tokens using AES
 * with managed IV and URL-safe Base64 encoding.
 */
public with sharing class TokenCryptoUtil {
	/**
	 * @description
	 * Encrypts plaintext using an AES key provided as a Base64 string.
	 *
	 * @param plaintext
	 * String to encrypt (e.g., JSON payload).
	 *
	 * @param base64Key
	 * AES key encoded as Base64 (must decode to 16 or 32 bytes).
	 *
	 * @return
	 * URL-safe encrypted token.
	 */
	public static String encryptToToken(String plaintext, String base64Key) {
		validateNotBlank(plaintext, 'Plaintext cannot be empty.');
		validateNotBlank(base64Key, 'Base64 key cannot be empty.');

		Blob keyBlob = EncodingUtil.base64Decode(base64Key);
		return encryptToToken(plaintext, keyBlob);
	}

	/**
	 * @description
	 * Encrypts plaintext using an AES key provided as a Blob.
	 *
	 * @param plaintext
	 * String to encrypt.
	 *
	 * @param keyBlob
	 * AES key as Blob (16 or 32 bytes).
	 *
	 * @return
	 * URL-safe encrypted token.
	 */
	public static String encryptToToken(String plaintext, Blob keyBlob) {
		validateKeyBlob(keyBlob);

		Blob plaintextBlob = Blob.valueOf(plaintext);
		String aesMode = resolveAESMode(keyBlob);

		Blob cipher = Crypto.encryptWithManagedIV(aesMode, keyBlob, plaintextBlob);

		return encodeBase64Url(cipher);
	}

	/**
	 * @description
	 * Decrypts an encrypted token using an AES key provided as a Base64 string.
	 *
	 * @param token
	 * URL-safe encrypted token.
	 *
	 * @param base64Key
	 * AES key encoded as Base64.
	 *
	 * @return
	 * Decrypted plaintext string.
	 */
	public static String decryptToken(String token, String base64Key) {
		validateNotBlank(token, 'Token cannot be empty.');
		validateNotBlank(base64Key, 'Base64 key cannot be empty.');

		Blob keyBlob = EncodingUtil.base64Decode(base64Key);
		return decryptToken(token, keyBlob);
	}

	/**
	 * @description
	 * Decrypts an encrypted token using an AES key provided as a Blob.
	 *
	 * @param token
	 * URL-safe encrypted token.
	 *
	 * @param keyBlob
	 * AES key as Blob.
	 *
	 * @return
	 * Decrypted plaintext string.
	 */
	public static String decryptToken(String token, Blob keyBlob) {
		validateKeyBlob(keyBlob);

		Blob cipher = decodeBase64Url(token);
		String aesMode = resolveAESMode(keyBlob);

		Blob plaintext = Crypto.decryptWithManagedIV(aesMode, keyBlob, cipher);

		return plaintext.toString();
	}

	/* =========================
       Validation Helpers
       ========================= */

	/**
	 * @description
	 * Validates that a string is not null or blank.
	 *
	 * @param value
	 * String to validate.
	 *
	 * @param errorMessage
	 * Error message to throw if validation fails.
	 */
	private static void validateNotBlank(String value, String errorMessage) {
		if (String.isBlank(value)) {
			throw new IllegalArgumentException(errorMessage);
		}
	}

	/**
	 * @description
	 * Validates that an AES key blob is present.
	 *
	 * @param keyBlob
	 * AES key as Blob.
	 */
	private static void validateKeyBlob(Blob keyBlob) {
		if (keyBlob == null) {
			throw new IllegalArgumentException('Key blob cannot be null.');
		}
	}

	/**
	 * @description
	 * Determines the AES mode based on key length.
	 *
	 * @param keyBlob
	 * AES key as Blob.
	 *
	 * @return
	 * AES algorithm name.
	 */
	private static String resolveAESMode(Blob keyBlob) {
		Integer keyLength = keyBlob.size();

		if (keyLength == 16) {
			return 'AES128';
		}

		if (keyLength == 32) {
			return 'AES256';
		}

		throw new IllegalArgumentException(
			'Unsupported AES key length: must be 16 or 32 bytes.'
		);
	}

	/* =========================
       Base64 URL Helpers
       ========================= */

	/**
	 * @description
	 * Encodes a Blob into URL-safe Base64 without padding.
	 *
	 * @param data
	 * Binary data to encode.
	 *
	 * @return
	 * URL-safe Base64 string.
	 */
	private static String encodeBase64Url(Blob data) {
		String base64 = EncodingUtil.base64Encode(data);

		return base64.replace('+', '-').replace('/', '_').replace('=', '');
	}

	/**
	 * @description
	 * Decodes a URL-safe Base64 string back into a Blob.
	 *
	 * @param token
	 * URL-safe Base64 string.
	 *
	 * @return
	 * Decoded Blob.
	 */
	private static Blob decodeBase64Url(String token) {
		validateNotBlank(token, 'Empty token.');

		String base64 = token.replace('-', '+').replace('_', '/');

		Integer paddingLength = calculatePadding(base64.length());

		if (paddingLength > 0) {
			base64 += String.valueOf('=').repeat(paddingLength);
		}

		return EncodingUtil.base64Decode(base64);
	}

	/**
	 * @description
	 * Calculates required Base64 padding length.
	 *
	 * @param length
	 * Length of the Base64 string.
	 *
	 * @return
	 * Number of padding characters required.
	 */
	private static Integer calculatePadding(Integer length) {
		Integer remainder = Math.mod(length, 4);

		if (remainder == 0) {
			return 0;
		}

		return 4 - remainder;
	}
}
