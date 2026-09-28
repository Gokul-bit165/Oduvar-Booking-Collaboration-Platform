/*
  Warnings:

  - You are about to drop the column `instruments` on the `oduvar_profiles` table. All the data in the column will be lost.
  - You are about to drop the column `max_duration` on the `oduvar_profiles` table. All the data in the column will be lost.
  - You are about to drop the column `min_duration` on the `oduvar_profiles` table. All the data in the column will be lost.
  - You are about to drop the column `skills` on the `oduvar_profiles` table. All the data in the column will be lost.
  - You are about to alter the column `bio` on the `oduvar_profiles` table. The data in that column could be lost. The data in that column will be cast from `Text` to `VarChar(1000)`.
  - You are about to alter the column `location` on the `oduvar_profiles` table. The data in that column could be lost. The data in that column will be cast from `Text` to `VarChar(200)`.
  - The `transport` column on the `oduvar_profiles` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- CreateEnum
CREATE TYPE "TransportOption" AS ENUM ('INCLUDED', 'NOT_INCLUDED', 'ADDITIONAL_FEE', 'TO_BE_DISCUSSED');

-- AlterTable
ALTER TABLE "oduvar_photos" ALTER COLUMN "display_order" SET DEFAULT 1;

-- AlterTable
ALTER TABLE "oduvar_profiles" DROP COLUMN "instruments",
DROP COLUMN "max_duration",
DROP COLUMN "min_duration",
DROP COLUMN "skills",
ADD COLUMN     "is_published" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "song_categories" TEXT[] DEFAULT ARRAY[]::TEXT[],
ALTER COLUMN "bio" SET DATA TYPE VARCHAR(1000),
ALTER COLUMN "location" SET DATA TYPE VARCHAR(200),
DROP COLUMN "transport",
ADD COLUMN     "transport" "TransportOption" NOT NULL DEFAULT 'TO_BE_DISCUSSED';

-- CreateTable
CREATE TABLE "skills" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "is_predefined" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "skills_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "oduvar_profile_skills" (
    "profile_id" UUID NOT NULL,
    "skill_id" UUID NOT NULL,

    CONSTRAINT "oduvar_profile_skills_pkey" PRIMARY KEY ("profile_id","skill_id")
);

-- CreateTable
CREATE TABLE "instruments" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "is_predefined" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "instruments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "oduvar_profile_instruments" (
    "profile_id" UUID NOT NULL,
    "instrument_id" UUID NOT NULL,

    CONSTRAINT "oduvar_profile_instruments_pkey" PRIMARY KEY ("profile_id","instrument_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "skills_name_key" ON "skills"("name");

-- CreateIndex
CREATE UNIQUE INDEX "skills_slug_key" ON "skills"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "instruments_name_key" ON "instruments"("name");

-- CreateIndex
CREATE UNIQUE INDEX "instruments_slug_key" ON "instruments"("slug");

-- AddForeignKey
ALTER TABLE "oduvar_profile_skills" ADD CONSTRAINT "oduvar_profile_skills_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "oduvar_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "oduvar_profile_skills" ADD CONSTRAINT "oduvar_profile_skills_skill_id_fkey" FOREIGN KEY ("skill_id") REFERENCES "skills"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "oduvar_profile_instruments" ADD CONSTRAINT "oduvar_profile_instruments_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "oduvar_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "oduvar_profile_instruments" ADD CONSTRAINT "oduvar_profile_instruments_instrument_id_fkey" FOREIGN KEY ("instrument_id") REFERENCES "instruments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
