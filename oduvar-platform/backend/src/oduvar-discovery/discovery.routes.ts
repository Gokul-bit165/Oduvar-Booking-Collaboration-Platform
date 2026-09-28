import { Router } from 'express';
import { discoveryController } from './discovery.controller';

export const discoveryRouter = Router();

// Public and read-only: no auth required, only published Oduvars are ever returned.
discoveryRouter.get('/', (req, res, next) => discoveryController.search(req, res, next));
