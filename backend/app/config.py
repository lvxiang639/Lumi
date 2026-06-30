from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://lingxi:lingxi@localhost:5432/lingxi"
    redis_url: str = "redis://localhost:6379/0"
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "lingxi"
    # Push notifications (empty = disabled, fcm/jpush/apns)
    push_provider: str = ""
    fcm_server_key: str = ""
    jpush_app_key: str = ""
    jpush_master_secret: str = ""
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7  # 7 days in minutes (10080)
    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com/v1"
    qwen_api_key: str = ""
    qwen_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    dashscope_api_url: str = "https://dashscope.aliyuncs.com/api/v1"
    cosyvoice_endpoint: str = ""
    deepseek_model_name: str = "deepseek-chat"
    chat_model_name: str = "deepseek-v4-flash"
    qwen_model_name: str = "qwen-plus"
    qwen_vision_model_name: str = "qwen-vl-plus"
    asr_model_name: str = "qwen3-asr-flash"
    tts_model_name: str = "qwen3-tts-flash-2025-11-27"
    tts_default_voice: str = "Cherry"
    searxng_url: str = "http://localhost:8080"
    weather_api_url: str = "https://wttr.in"
    searxng_engines: str = "baidu,sogou,bing"
    notification_check_interval: int = 60
    # SMTP — configure via .env, defaults are empty (must be set to send email)
    smtp_host: str = ""
    smtp_port: int = 465
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from_email: str = ""

    model_config = {"env_file": ".env", "protected_namespaces": ()}

settings = Settings()
