-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "currency_snapshot" TEXT DEFAULT 'INR',
ADD COLUMN     "duration_snapshot" INTEGER,
ADD COLUMN     "pricing_id" UUID,
ADD COLUMN     "service_amount_snapshot" DECIMAL(10,2),
ADD COLUMN     "service_id" UUID,
ADD COLUMN     "service_name_snapshot" TEXT,
ADD COLUMN     "transport_fee_snapshot" DECIMAL(10,2),
ADD COLUMN     "transport_snapshot" TEXT;

-- CreateTable
CREATE TABLE "services" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "category" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "services_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "oduvar_services" (
    "id" UUID NOT NULL,
    "profile_id" UUID NOT NULL,
    "service_id" UUID NOT NULL,
    "custom_description" TEXT,
    "transport" "TransportOption" NOT NULL DEFAULT 'TO_BE_DISCUSSED',
    "transport_fee" DECIMAL(10,2),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "oduvar_services_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "service_pricings" (
    "id" UUID NOT NULL,
    "oduvar_service_id" UUID NOT NULL,
    "duration_minutes" INTEGER NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "service_pricings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "services_name_key" ON "services"("name");

-- CreateIndex
CREATE UNIQUE INDEX "oduvar_services_profile_id_service_id_key" ON "oduvar_services"("profile_id", "service_id");

-- CreateIndex
CREATE UNIQUE INDEX "service_pricings_oduvar_service_id_duration_minutes_key" ON "service_pricings"("oduvar_service_id", "duration_minutes");

-- AddForeignKey
ALTER TABLE "oduvar_services" ADD CONSTRAINT "oduvar_services_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "oduvar_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "oduvar_services" ADD CONSTRAINT "oduvar_services_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_pricings" ADD CONSTRAINT "service_pricings_oduvar_service_id_fkey" FOREIGN KEY ("oduvar_service_id") REFERENCES "oduvar_services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

