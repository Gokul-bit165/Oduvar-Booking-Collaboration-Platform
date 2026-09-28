-- AlterTable
ALTER TABLE "oduvar_profiles" ADD COLUMN     "event_types" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- CreateIndex
CREATE INDEX "oduvar_profile_instruments_instrument_id_idx" ON "oduvar_profile_instruments"("instrument_id");

-- CreateIndex
CREATE INDEX "oduvar_profiles_is_published_idx" ON "oduvar_profiles"("is_published");

-- CreateIndex
CREATE INDEX "oduvar_services_service_id_is_active_idx" ON "oduvar_services"("service_id", "is_active");

-- CreateIndex
CREATE INDEX "reviews_oduvar_id_idx" ON "reviews"("oduvar_id");
