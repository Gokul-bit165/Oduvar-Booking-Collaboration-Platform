-- CreateEnum
CREATE TYPE "DayOfWeek" AS ENUM ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY');

-- CreateEnum
CREATE TYPE "OverrideType" AS ENUM ('UNAVAILABLE', 'AVAILABLE');

-- AlterTable
ALTER TABLE "oduvar_profiles" ADD COLUMN     "buffer_minutes" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "maximum_duration_minutes" INTEGER NOT NULL DEFAULT 180,
ADD COLUMN     "minimum_duration_minutes" INTEGER NOT NULL DEFAULT 30,
ADD COLUMN     "timezone" TEXT NOT NULL DEFAULT 'Asia/Kolkata';

-- CreateTable
CREATE TABLE "oduvar_weekly_availability" (
    "id" UUID NOT NULL,
    "oduvar_id" UUID NOT NULL,
    "day_of_week" "DayOfWeek" NOT NULL,
    "start_time" TEXT NOT NULL,
    "end_time" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "oduvar_weekly_availability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "oduvar_availability_overrides" (
    "id" UUID NOT NULL,
    "oduvar_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "type" "OverrideType" NOT NULL,
    "start_time" TEXT,
    "end_time" TEXT,
    "reason" VARCHAR(200),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "oduvar_availability_overrides_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "oduvar_weekly_availability_oduvar_id_day_of_week_idx" ON "oduvar_weekly_availability"("oduvar_id", "day_of_week");

-- CreateIndex
CREATE INDEX "oduvar_availability_overrides_oduvar_id_date_idx" ON "oduvar_availability_overrides"("oduvar_id", "date");

-- AddForeignKey
ALTER TABLE "oduvar_weekly_availability" ADD CONSTRAINT "oduvar_weekly_availability_oduvar_id_fkey" FOREIGN KEY ("oduvar_id") REFERENCES "oduvar_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "oduvar_availability_overrides" ADD CONSTRAINT "oduvar_availability_overrides_oduvar_id_fkey" FOREIGN KEY ("oduvar_id") REFERENCES "oduvar_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

